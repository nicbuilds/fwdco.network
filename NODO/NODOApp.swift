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
    var body: some View {
        TabView {
            PortalScreen(portal: projects).tabItem { Label("Proyectos", systemImage: "square.stack.3d.up") }
            PortalScreen(portal: invoices).tabItem { Label("Cotizaciones", systemImage: "doc.text") }
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
            }.tabItem { Label("Ajustes", systemImage: "gearshape") }
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
