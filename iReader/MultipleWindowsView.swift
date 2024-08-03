import SwiftUI
import WebKit

// WebView to display full-screen webpage using WKWebView
struct WebView: UIViewRepresentable {
    let url: String

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: url) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}

// Function to capture thumbnail from a URL
func captureThumbnail(from url: String, completion: @escaping (UIImage?) -> Void) {
    print("Starting to capture thumbnail for URL: \(url)")
    let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    if let url = URL(string: url) {
        let request = URLRequest(url: url)
        webView.load(request)
        webView.navigationDelegate = WebViewNavigationDelegate { webView in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let config = WKSnapshotConfiguration()
                webView.takeSnapshot(with: config) { image, error in
                    if let error = error {
                        print("Error capturing thumbnail: \(error)")
                        completion(nil)
                    } else {
                        print("Successfully captured thumbnail for URL: \(url)")
                        completion(image)
                    }
                }
            }
        }
    } else {
        print("Invalid URL: \(url)")
        completion(nil)
    }
}

// WebView navigation delegate to detect when loading is complete
class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private let onComplete: (WKWebView) -> Void

    init(onComplete: @escaping (WKWebView) -> Void) {
        self.onComplete = onComplete
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Finished loading URL: \(webView.url?.absoluteString ?? "unknown")")
        onComplete(webView)
    }
}

// Data model for a webpage window
struct WebPageWindow: Identifiable {
    let id = UUID()
    var thumbnail: UIImage?
    let title: String
    let url: String
}

// Main view to display multiple webpage windows
struct MultipleWindowsView: View {
    @State private var webPageWindows = [
        WebPageWindow(thumbnail: nil, title: "Webpage 1", url: "https://www.baidu.com"),
        WebPageWindow(thumbnail: nil, title: "Webpage 2", url: "https://www.bing.com"),
        WebPageWindow(thumbnail: nil, title: "Webpage 3", url: "https://www.360.com"),
        WebPageWindow(thumbnail: nil, title: "Webpage 4", url: "https://www.bilibili.com"),
        WebPageWindow(thumbnail: nil, title: "Webpage 5", url: "https://www.youku.com")
    ]
    
    @State private var showFullScreen = false
    @State private var selectedWebPage: WebPageWindow?
    @State private var selectedTab = 0
    
    // Define the grid layout
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Picker("", selection: $selectedTab) {
                        Text("普通窗口").tag(0)
                        Text("无痕窗口").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(EdgeInsets(top: 0, leading: 80, bottom: 0, trailing: 80))
                }
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(webPageWindows) { window in
                            VStack {
                                ZStack(alignment: .topTrailing) {
                                    Button(action: {
                                        selectedWebPage = window
                                        showFullScreen.toggle()
                                    }) {
                                        if let thumbnail = window.thumbnail {
                                            Image(uiImage: thumbnail)
                                                .resizable()
                                                .frame(width: 150, height: 250)
                                                .cornerRadius(10)
                                                .shadow(radius: 5)
                                        } else {
                                            ProgressView()  // Show progress indicator while loading thumbnail
                                                .frame(width: 150, height: 250)
                                                .cornerRadius(10)
                                                .shadow(radius: 5)
                                                .onAppear {
                                                    print("Attempting to capture thumbnail for \(window.title)")
                                                    captureThumbnail(from: window.url) { image in
                                                        DispatchQueue.main.async {
                                                            if let index = webPageWindows.firstIndex(where: { $0.id == window.id }) {
                                                                print("Updating thumbnail for \(window.title)")
                                                                webPageWindows[index].thumbnail = image
                                                            }
                                                        }
                                                    }
                                                }
                                        }
                                    }
                                    
                                    Button(action: {
                                        if let index = webPageWindows.firstIndex(where: { $0.id == window.id }) {
                                            webPageWindows.remove(at: index)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .padding(5)
                                    }
                                }
                                Text(window.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(maxWidth: 150)
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                Button(action: {
                    addNewWebPageWindow()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .padding()
                }
            }
            .fullScreenCover(item: $selectedWebPage) { webpage in
                FullScreenWebView(url: webpage.url) {
                    showFullScreen = false
                    selectedWebPage = nil
                }
            }
        }
    }
    
    // Function to add a new webpage window
    private func addNewWebPageWindow() {
        let newWindow = WebPageWindow(thumbnail: nil, title: "New Webpage", url: "https://www.baidu.com")
        webPageWindows.append(newWindow)
        captureThumbnail(from: newWindow.url) { image in
            DispatchQueue.main.async {
                if let index = webPageWindows.firstIndex(where: { $0.id == newWindow.id }) {
                    webPageWindows[index].thumbnail = image
                }
            }
        }
    }
}

// Full-screen WebView with Done button
struct FullScreenWebView: View {
    let url: String
    var onClose: () -> Void
    
    var body: some View {
        NavigationView {
            WebView(url: url)
                .navigationBarItems(trailing: Button("Done") {
                    onClose()
                })
        }
    }
}

// Preview
struct MultipleWindowsView_Previews: PreviewProvider {
    static var previews: some View {
        MultipleWindowsView()
    }
}
