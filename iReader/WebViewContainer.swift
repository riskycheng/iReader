import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @Binding var url: URL?
    @Binding var currentURL: URL?
    var onLoadCompletion: (URL?) -> Void // Pass a closure to handle URL load completion

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = url {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.navigationDelegate = nil
        uiView.stopLoading()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewContainer

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.currentURL = webView.url // Update the currentURL when navigation finishes
            parent.onLoadCompletion(webView.url) // Notify parent about URL load completion
            print("Navigating to: \(webView.url?.absoluteString ?? "Unknown")")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Failed to load \(webView.url?.absoluteString ?? "Unknown"): \(error.localizedDescription)")
        }
    }
}
