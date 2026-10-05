import SwiftUI
import WebKit
import UIKit

@main
struct NODOApp: App {
    var body: some Scene { WindowGroup { Dashboard() } }
}

struct Dashboard: View {
    @StateObject private var projects = Portal(title: "Proyectos", address: "https://pm.nodo.help")
    @StateObject private var invoices = Portal(title: "Cotizaciones y pagos", address: "https://invoice.nodo.help")
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            PortalScreen(portal: projects).tabItem { Label("Proyectos", systemImage: "square.stack.3d.up") }.tag(0)
            PortalScreen(portal: invoices).tabItem { Label("InvoicePlane", systemImage: "doc.text") }.tag(1)
            StudioScreen(invoicePortal: invoices, selectedTab: $selectedTab)
                .tabItem { Label("Crear", systemImage: "plus.square") }.tag(2)
            NavigationStack {
                List {
                    Section {
                        Text("NODO").font(.largeTitle.bold()).foregroundStyle(Color.purple)
                        Text("Tu consultoría, conectada.")
                    }
                    Section("Tu operación") {
                        Label("Rukovoditel · proyectos y documentos", systemImage: "folder")
                        Label("InvoicePlane · cotizaciones y pagos", systemImage: "doc.text")
                        Text("Inicia sesión en cada sistema con tu cuenta habitual. Los permisos y la sincronización los administra tu servidor.")
                    }
                    Section("Sesiones") {
                        Text("Para cerrar sesión usa Salir en cada sistema. Borrar sesiones elimina las cookies de ambos portales en este dispositivo.")
                        Button("Borrar sesiones", role: .destructive) { showReset = true }
                    }
                    Section("Versión 1.0") {
                        Text("Requiere conexión a internet. Las pantallas operativas son las interfaces web de tus sistemas. Los enlaces externos se abren fuera de NODO.")
                    }
                }.navigationTitle("NODO")
                .confirmationDialog("¿Borrar las sesiones de ambos sistemas?", isPresented: $showReset, titleVisibility: .visible) {
                    Button("Borrar sesiones", role: .destructive) {
                        projects.web.stopLoading(); invoices.web.stopLoading()
                        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
                            projects.home(); invoices.home()
                        }
                    }
                }
            }.tabItem { Label("Ajustes", systemImage: "gearshape") }.tag(3)
        }.tint(Color(red: 0.43, green: 0.34, blue: 0.65))
    }
    @State private var showReset = false
}

struct PortalScreen: View {
    @ObservedObject var portal: Portal
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if portal.loading { ProgressView().frame(maxWidth: .infinity).padding(5) }
                if let error = portal.error {
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                        Text("No se pudo abrir el portal").font(.headline)
                        Text(error).font(.subheadline).multilineTextAlignment(.center)
                        Button("Reintentar") { portal.home() }.buttonStyle(.borderedProminent)
                    }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else { PortalWeb(portal: portal) }
            }
            .navigationTitle(portal.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { portal.web.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!portal.canBack).accessibilityLabel("Atrás")
                    Button { portal.web.goForward() } label: { Image(systemName: "chevron.right") }.disabled(!portal.canForward).accessibilityLabel("Adelante")
                    Spacer()
                    Button { portal.home() } label: { Image(systemName: "house") }.accessibilityLabel("Inicio del portal")
                    Button { portal.web.reload() } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Recargar")
                    Button { if let url = portal.web.url { UIApplication.shared.open(url) } } label: { Image(systemName: "safari") }.accessibilityLabel("Abrir en Safari")
                }
            }
        }
    }
}

struct PortalWeb: UIViewRepresentable {
    let portal: Portal
    func makeUIView(context: Context) -> WKWebView { portal.web }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

final class Portal: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    let title: String
    let root: URL
    let web: WKWebView
    @Published var loading = false
    @Published var canBack = false
    @Published var canForward = false
    @Published var error: String?
    private var observations: [NSKeyValueObservation] = []
    private var destinations: [ObjectIdentifier: URL] = [:]

    init(title: String, address: String) {
        self.title = title
        self.root = URL(string: address)!
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        web = WKWebView(frame: .zero, configuration: config)
        super.init()
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        for keyPath in [\WKWebView.canGoBack, \WKWebView.canGoForward, \WKWebView.isLoading] {
            observations.append(web.observe(keyPath, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.canBack = self.web.canGoBack
                    self.canForward = self.web.canGoForward
                    self.loading = self.web.isLoading
                }
            })
        }
        home()
    }
    func home() { error = nil; web.load(URLRequest(url: root)) }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { error = nil }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError issue: Error) { failed(issue) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError issue: Error) { failed(issue) }
    private func failed(_ issue: Error) {
        if (issue as NSError).code != NSURLErrorCancelled { error = issue.localizedDescription }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if url.scheme == "about" || url.scheme == "blob" { decisionHandler(.allow); return }
        let hosts = ["pm.nodo.help", "invoice.nodo.help"]
        if url.scheme == "https", hosts.contains(url.host?.lowercased() ?? "") {
            decisionHandler(action.shouldPerformDownload ? .download : .allow)
        } else {
            decisionHandler(.cancel)
            if ["https", "mailto", "tel"].contains(url.scheme ?? ""), action.navigationType == .linkActivated { UIApplication.shared.open(url) }
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let disposition = (response.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        decisionHandler(!response.canShowMIMEType || disposition.lowercased().contains("attachment") ? .download : .allow)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil { webView.load(action.request) }; return nil
    }
    private var presenter: UIViewController? {
        var controller = web.window?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard let presenter = presenter else { completionHandler(); return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default) { _ in completionHandler() })
        presenter.present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard let presenter = presenter else { completionHandler(false); return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default) { _ in completionHandler(true) })
        presenter.present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        guard let presenter = presenter else { completionHandler(nil); return }
        let alert = UIAlertController(title: title, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default) { _ in completionHandler(alert.textFields?.first?.text) })
        presenter.present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent((suggestedFilename as NSString).lastPathComponent)
            destinations[ObjectIdentifier(download)] = file
            completionHandler(file)
        } catch { completionHandler(nil) }
    }
    func downloadDidFinish(_ download: WKDownload) {
        guard let file = destinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
        guard let presenter = presenter else { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()); return }
        let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = web
        share.popoverPresentationController?.sourceRect = CGRect(x: web.bounds.midX, y: web.bounds.midY, width: 1, height: 1)
        share.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        presenter.present(share, animated: true)
    }
    func download(_ download: WKDownload, didFailWithError issue: Error, resumeData: Data?) {
        if let file = destinations.removeValue(forKey: ObjectIdentifier(download)) { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        guard let presenter = presenter else { return }
        let alert = UIAlertController(title: "No se pudo descargar", message: issue.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default))
        presenter.present(alert, animated: true)
    }
}

// Independent iOS forms. The bridge uses the already authenticated InvoicePlane session.
private struct StudioClient: Decodable, Identifiable {
    let client_id: String
    let client_name: String
    let client_email: String?
    let client_company: String?
    var id: String { client_id }
}
private struct StudioGroup: Decodable, Identifiable {
    let invoice_group_id: String
    let invoice_group_name: String
    var id: String { invoice_group_id }
}
private struct StudioTax: Decodable, Identifiable {
    let tax_rate_id: String
    let tax_rate_name: String
    let tax_rate_percent: String
    var id: String { tax_rate_id }
}
private struct StudioBootstrap: Decodable {
    let csrf_name: String
    let csrf_hash: String
    let clients: [StudioClient]
    let groups: [StudioGroup]
    let tax_rates: [StudioTax]
    let default_group_id: Int
}
private struct StudioResponse: Decodable {
    let client_id: Int?
    let quote_id: Int?
    let error: String?
}
private struct StudioLine: Identifiable, Encodable {
    var id = UUID()
    var name = ""
    var quantity = "1"
    var price = ""
    var tax_rate_id = 0
    enum CodingKeys: String, CodingKey { case name, quantity, price, tax_rate_id }
}
private struct StudioPayload: Encodable {
    let client_id: Int
    let group_id: Int
    let items: [StudioLine]
}
private struct NewClient: Encodable {
    let name: String
    let email: String
    let phone: String
    let company: String
}

@MainActor
private final class StudioModel: ObservableObject {
    @Published var bootstrap: StudioBootstrap?
    @Published var busy = false
    @Published var notice = ""
    @Published var clientID = ""
    @Published var groupID = ""
    @Published var lastQuoteID: Int?
    private let endpoint = URL(string: "https://invoice.nodo.help/index.php/nodo_api")!
    private let cookieStore = WKWebsiteDataStore.default().httpCookieStore

    private func syncCookies() async {
        let cookies = await withCheckedContinuation { continuation in
            cookieStore.getAllCookies { continuation.resume(returning: $0) }
        }
        for cookie in cookies where cookie.domain.lowercased().hasSuffix("invoice.nodo.help") {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }
    private func request(_ path: String = "", fields: [String: String]? = nil) async throws -> Data {
        await syncCookies()
        var req = URLRequest(url: path.isEmpty ? endpoint : endpoint.appendingPathComponent(path))
        req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let fields {
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
            req.httpBody = fields.map { key, value in
                "\(key.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
            }.joined(separator: "&").data(using: .utf8)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw StudioError.message("Sin respuesta del servidor.") }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(StudioResponse.self, from: data).error)
            if http.statusCode == 401 || http.statusCode == 403 {
                throw StudioError.message("Inicia sesión como administrador en la pestaña InvoicePlane y vuelve a intentarlo.")
            }
            if http.statusCode == 404 {
                throw StudioError.message("Falta instalar el conector NODO en InvoicePlane.")
            }
            throw StudioError.message(message ?? "Error del servidor (\(http.statusCode)).")
        }
        return data
    }
    func refresh() async {
        busy = true
        defer { busy = false }
        do {
            let value = try JSONDecoder().decode(StudioBootstrap.self, from: try await request())
            bootstrap = value
            if !value.clients.contains(where: { $0.client_id == clientID }) { clientID = value.clients.first?.client_id ?? "" }
            if !value.groups.contains(where: { $0.invoice_group_id == groupID }) {
                groupID = String(value.default_group_id)
                if !value.groups.contains(where: { $0.invoice_group_id == groupID }) { groupID = value.groups.first?.invoice_group_id ?? "" }
            }
            notice = ""
        } catch { notice = error.localizedDescription }
    }
    private func submit<T: Encodable>(_ value: T, path: String) async throws -> StudioResponse {
        // The first GET supplies a fresh CSRF value. Its response cookie remains in URLSession.
        let current = try JSONDecoder().decode(StudioBootstrap.self, from: try await request())
        let body = String(data: try JSONEncoder().encode(value), encoding: .utf8)!
        return try JSONDecoder().decode(StudioResponse.self, from: try await request(path, fields: [current.csrf_name: current.csrf_hash, "payload": body]))
    }
    func createClient(name: String, email: String, phone: String, company: String) async -> Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              email.contains("@") else { notice = "Escribe el nombre y un correo válido."; return false }
        busy = true
        defer { busy = false }
        do {
            let result = try await submit(NewClient(name: name, email: email, phone: phone, company: company), path: "create_client")
            guard let id = result.client_id else { throw StudioError.message("InvoicePlane no devolvió el cliente creado.") }
            let fresh = try JSONDecoder().decode(StudioBootstrap.self, from: try await request())
            bootstrap = fresh
            clientID = String(id)
            notice = "Cliente guardado en InvoicePlane."
            return true
        } catch { notice = error.localizedDescription; return false }
    }
    func createQuote(lines: [StudioLine]) async {
        guard let client = Int(clientID), let group = Int(groupID), !lines.isEmpty,
              lines.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespaces).isEmpty &&
                  (Double($0.quantity.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 &&
                  (Double($0.price.replacingOccurrences(of: ",", with: ".")) ?? -1) >= 0 })
        else { notice = "Selecciona cliente y grupo; revisa los conceptos, cantidades y precios."; return }
        let clean = lines.map { item in
            StudioLine(id: item.id, name: item.name, quantity: item.quantity.replacingOccurrences(of: ",", with: "."),
                       price: item.price.replacingOccurrences(of: ",", with: "."), tax_rate_id: item.tax_rate_id)
        }
        busy = true
        defer { busy = false }
        do {
            let result = try await submit(StudioPayload(client_id: client, group_id: group, items: clean), path: "create_quote")
            guard let id = result.quote_id else { throw StudioError.message("InvoicePlane no devolvió la cotización.") }
            lastQuoteID = id
            notice = "Cotización #\(id) creada como borrador en InvoicePlane."
        } catch { notice = error.localizedDescription }
    }
    private enum StudioError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case let .message(value) = self { return value }; return nil }
    }
}

private struct StudioScreen: View {
    let invoicePortal: Portal
    @Binding var selectedTab: Int
    @StateObject private var model = StudioModel()
    @State private var showingClient = false
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var company = ""
    @State private var lines = [StudioLine()]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Crea clientes y cotizaciones en InvoicePlane desde esta pantalla.")
                    if !model.notice.isEmpty { Text(model.notice).foregroundStyle(.secondary) }
                    if model.bootstrap == nil {
                        Button("Conectar con InvoicePlane") { Task { await model.refresh() } }
                    }
                }
                if let data = model.bootstrap {
                    Section("Cliente") {
                        Picker("Cliente", selection: $model.clientID) {
                            ForEach(data.clients) { client in Text(client.client_name).tag(client.client_id) }
                        }
                        Button("Crear cliente nuevo") { showingClient = true }
                    }
                    Section("Cotización") {
                        Picker("Grupo de cotización", selection: $model.groupID) {
                            ForEach(data.groups) { group in Text(group.invoice_group_name).tag(group.invoice_group_id) }
                        }
                        ForEach($lines) { $line in
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Concepto", text: $line.name)
                                HStack {
                                    TextField("Cantidad", text: $line.quantity).keyboardType(.decimalPad)
                                    TextField("Precio unitario", text: $line.price).keyboardType(.decimalPad)
                                }
                                Picker("Impuesto", selection: $line.tax_rate_id) {
                                    Text("Sin impuesto").tag(0)
                                    ForEach(data.tax_rates) { rate in
                                        Text("\(rate.tax_rate_name) (\(rate.tax_rate_percent)%)")
                                            .tag(Int(rate.tax_rate_id) ?? 0)
                                    }
                                }
                            }.padding(.vertical, 5)
                        }
                        Button("Añadir concepto") { lines.append(StudioLine()) }
                        if lines.count > 1 { Button("Quitar último", role: .destructive) { lines.removeLast() } }
                    }
                    Section {
                        Button("Crear borrador en InvoicePlane") { Task { await model.createQuote(lines: lines) } }
                            .disabled(model.busy || model.clientID.isEmpty)
                        if let id = model.lastQuoteID {
                            Button("Abrir cotización #\(id)") {
                                invoicePortal.web.load(URLRequest(url: URL(string: "https://invoice.nodo.help/index.php/quotes/view/\(id)")!))
                                selectedTab = 1
                            }
                        }
                    }
                }
            }
            .navigationTitle("Crear")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
            } }
            .overlay { if model.busy { ProgressView().padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12)) } }
            .task { if model.bootstrap == nil { await model.refresh() } }
            .sheet(isPresented: $showingClient) {
                NavigationStack {
                    Form {
                        TextField("Nombre o razón social *", text: $name)
                        TextField("Correo *", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        TextField("Teléfono", text: $phone).keyboardType(.phonePad)
                        TextField("Empresa", text: $company)
                        if !model.notice.isEmpty { Text(model.notice).foregroundStyle(.secondary) }
                        Button("Guardar cliente") {
                            Task {
                                if await model.createClient(name: name, email: email, phone: phone, company: company) {
                                    name = ""; email = ""; phone = ""; company = ""; showingClient = false
                                }
                            }
                        }.disabled(model.busy)
                    }
                    .navigationTitle("Nuevo cliente")
                    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Cerrar") { showingClient = false } } }
                }
            }
        }
    }
}
