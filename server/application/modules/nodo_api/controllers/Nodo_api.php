<?php

defined('BASEPATH') || exit('No direct script access allowed');

/** NODO iOS bridge for InvoicePlane 1.6; authenticated administrator session required. */
class Nodo_api extends Admin_Controller
{
    public function __construct()
    {
        parent::__construct();
        $this->output->set_content_type('application/json', 'utf-8');
        $this->output->set_header('Cache-Control: no-store');
    }

    private function respond(array $body, int $status = 200): void
    {
        $this->output->set_status_header($status)->set_output(json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }

    private function payload(): ?array
    {
        if ($this->input->method(true) !== 'POST') {
            $this->respond(['error' => 'Se requiere POST.'], 405);
            return null;
        }
        $raw = $this->input->post('payload', false);
        if (!is_string($raw) || strlen($raw) > 24000) {
            $this->respond(['error' => 'Solicitud demasiado grande o ausente.'], 400);
            return null;
        }
        $data = json_decode($raw, true);
        if (!is_array($data) || json_last_error() !== JSON_ERROR_NONE) {
            $this->respond(['error' => 'JSON inválido.'], 400);
            return null;
        }
        return $data;
    }

    public function index(): void
    {
        if ($this->input->method(true) !== 'GET') {
            $this->respond(['error' => 'Se requiere GET.'], 405);
            return;
        }
        $clients = $this->db->select('client_id, client_name, client_email, client_company')
            ->from('ip_clients')->where('client_active', 1)->order_by('client_name')->limit(500)->get()->result_array();
        $groups = $this->db->select('invoice_group_id, invoice_group_name')
            ->from('ip_invoice_groups')->order_by('invoice_group_name')->get()->result_array();
        $rates = $this->db->select('tax_rate_id, tax_rate_name, tax_rate_percent')
            ->from('ip_tax_rates')->order_by('tax_rate_name')->get()->result_array();
        $this->respond([
            'csrf_name' => $this->security->get_csrf_token_name(),
            'csrf_hash' => $this->security->get_csrf_hash(),
            'clients' => $clients,
            'groups' => $groups,
            'tax_rates' => $rates,
            'default_group_id' => (int) get_setting('default_quote_group'),
        ]);
    }

    public function create_client(): void
    {
        $data = $this->payload();
        if ($data === null) return;
        $name = trim((string) ($data['name'] ?? ''));
        $email = trim((string) ($data['email'] ?? ''));
        $phone = trim((string) ($data['phone'] ?? ''));
        $company = trim((string) ($data['company'] ?? ''));
        if ($name === '' || strlen($name) > 150 || strlen($company) > 150 || strlen($phone) > 50 || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->respond(['error' => 'Revisa nombre, correo, teléfono y empresa.'], 422);
            return;
        }
        $already = $this->db->select('client_id')->from('ip_clients')->where('client_name', $name)->where('client_email', $email)->limit(1)->get()->row();
        if ($already) {
            $this->respond(['error' => 'Ya existe un cliente con ese nombre y correo.'], 409);
            return;
        }
        $this->load->model('clients/mdl_clients');
        $id = $this->mdl_clients->save(null, [
            'client_name' => $name, 'client_email' => $email,
            'client_phone' => $phone, 'client_company' => $company,
            'client_active' => 1,
        ]);
        if (!$id) {
            $this->respond(['error' => 'InvoicePlane no pudo guardar el cliente.'], 500);
            return;
        }
        $this->respond(['client_id' => (int) $id], 201);
    }

    public function create_quote(): void
    {
        $data = $this->payload();
        if ($data === null) return;
        $clientId = filter_var($data['client_id'] ?? null, FILTER_VALIDATE_INT);
        $groupId = filter_var($data['group_id'] ?? null, FILTER_VALIDATE_INT);
        $items = $data['items'] ?? null;
        if (!$clientId || !$groupId || !is_array($items) || count($items) < 1 || count($items) > 30) {
            $this->respond(['error' => 'Selecciona cliente, grupo y al menos un concepto.'], 422);
            return;
        }
        if (!$this->db->get_where('ip_clients', ['client_id' => $clientId, 'client_active' => 1])->row() ||
            !$this->db->get_where('ip_invoice_groups', ['invoice_group_id' => $groupId])->row()) {
            $this->respond(['error' => 'Cliente o grupo inexistente.'], 422);
            return;
        }
        $lines = [];
        foreach ($items as $item) {
            if (!is_array($item)) { $this->respond(['error' => 'Concepto inválido.'], 422); return; }
            $name = trim((string) ($item['name'] ?? ''));
            $quantity = filter_var($item['quantity'] ?? null, FILTER_VALIDATE_FLOAT);
            $price = filter_var($item['price'] ?? null, FILTER_VALIDATE_FLOAT);
            $tax = (int) ($item['tax_rate_id'] ?? 0);
            if ($name === '' || strlen($name) > 150 || $quantity === false || $quantity <= 0 || $quantity > 100000 ||
                $price === false || $price < 0 || $price > 100000000 || $tax < 0) {
                $this->respond(['error' => 'Revisa nombre, cantidad, precio e impuesto.'], 422); return;
            }
            if ($tax > 0 && !$this->db->get_where('ip_tax_rates', ['tax_rate_id' => $tax])->row()) {
                $this->respond(['error' => 'Tasa de impuesto inexistente.'], 422); return;
            }
            $lines[] = ['name' => $name, 'quantity' => $quantity, 'price' => $price, 'tax' => $tax];
        }
        $this->load->model(['quotes/mdl_quotes', 'quotes/mdl_quote_items']);
        $date = date('Y-m-d');
        $number = (int) get_setting('generate_quote_number_for_draft') === 1
            ? $this->mdl_quotes->get_quote_number($groupId) : '';
        $record = [
            'client_id' => $clientId,
            'user_id' => (int) $this->session->userdata('user_id'),
            'invoice_group_id' => $groupId,
            'quote_status_id' => 1,
            'quote_date_created' => $date,
            'quote_date_expires' => $this->mdl_quotes->get_date_due($date),
            'quote_number' => $number,
            'quote_url_key' => $this->mdl_quotes->get_url_key(),
            'notes' => get_setting('default_quote_notes'),
        ];
        $this->db->trans_begin();
        try {
            $id = $this->mdl_quotes->create($record);
            if (!$id) throw new RuntimeException('No se creó la cotización.');
            $discount = ['amount' => 0.0, 'percent' => 0.0, 'item' => 0.0, 'items_subtotal' => 0.0];
            foreach ($lines as $order => $line) {
                $this->mdl_quote_items->save(null, [
                    'quote_id' => $id,
                    'item_name' => $line['name'],
                    'item_description' => '',
                    'item_quantity' => $line['quantity'],
                    'item_price' => $line['price'],
                    'item_tax_rate_id' => $line['tax'],
                    'item_order' => $order + 1,
                ], $discount);
            }
            if ($this->db->trans_status() === false) throw new RuntimeException('Falló el cálculo de InvoicePlane.');
            $this->db->trans_commit();
            $this->respond(['quote_id' => (int) $id], 201);
        } catch (Throwable $e) {
            $this->db->trans_rollback();
            log_message('error', 'NODO API quote failure: ' . $e->getMessage());
            $this->respond(['error' => 'No se pudo guardar la cotización.'], 500);
        }
    }
}
