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

struct MultipleWindowsView: View {
    @State private var selectedTab = 0
    
    let urls: [URL] = [
        URL(string: "https://www.baidu.com")!,
        URL(string: "https://www.icloud.com")!,
        // Add more URLs as needed
    ]
    
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
                        Image(systemName: "plus")
                            .padding(.trailing, 20)
                            .frame(height: geometry.size.height / 2, alignment: .center)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                )
                
                TabView(selection: $selectedTab) {
                    ForEach(0..<urls.count, id: \.self) { index in
                        WebView(url: urls[index])
                            .tabItem {
                                Text("Page \(index + 1)")
                            }
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
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
