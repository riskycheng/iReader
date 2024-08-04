import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

struct GridView: View {
    let urls: [URL]
    let onSelect: (URL) -> Void
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.fixed(150)), GridItem(.fixed(150))], spacing: 20) {
                ForEach(urls, id: \.self) { url in
                    Button(action: {
                        onSelect(url)
                    }) {
                        VStack {
                            WebView(url: url)
                                .frame(height: 150)
                                .cornerRadius(10)
                                .padding()
                            Text(url.host ?? "")
                                .font(.caption)
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                    }
                }
            }
            .padding()
        }
    }
}

struct MultipleWindowsView: View {
    @State private var selectedTab = 0
    @State private var isFullScreen = false
    @State private var selectedURL: URL?
    @State private var urls: [URL] = [
        URL(string: "https://www.baidu.com")!,
        URL(string: "https://www.icloud.com")!,
        URL(string: "https://www.example.com")!
    ]
    
    func addNewPage() {
        let newURLString = "https://www.newpage\(urls.count + 1).com"
        if let newURL = URL(string: newURLString) {
            urls.append(newURL)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("普通窗口").tag(0)
                    Text("无痕窗口").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(EdgeInsets(top: 0, leading: 80, bottom: 0, trailing: 80))
                .background(
                    HStack {
                        Spacer()
                        if selectedTab == 0 {
                            Button(action: {
                                if isFullScreen {
                                    isFullScreen.toggle()
                                } else {
                                    addNewPage()
                                }
                            }) {
                                Image(systemName: isFullScreen ? "rectangle.stack" : "plus")
                                    .padding(.trailing, 20)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                )
                
                if isFullScreen, let url = selectedURL {
                    WebView(url: url)
                } else {
                    GridView(urls: urls) { url in
                        selectedURL = url
                        isFullScreen = true
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct MultipleWindowsView_Previews: PreviewProvider {
    static var previews: some View {
        MultipleWindowsView()
    }
}
