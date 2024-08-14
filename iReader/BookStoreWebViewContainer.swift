import SwiftUI
import WebKit

struct BookStoreWebViewContainer: View {
    @State private var currentURL: URL?
    var initialURL: URL
    
    var body: some View {
        VStack {
            WebViewContainer(url: $currentURL)
                .onAppear {
                    currentURL = initialURL
                }
                .edgesIgnoringSafeArea(.all)
        }
    }
}
