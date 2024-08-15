import SwiftUI

struct BookStoreWebViewContainer: View {
    @State private var currentURL: URL?
    var initialURL: URL
    
    var body: some View {
        VStack {
            WebViewContainer(url: $currentURL, currentURL: $currentURL)
                .onAppear {
                    currentURL = initialURL
                }
                .edgesIgnoringSafeArea(.all)
        }
        .navigationBarTitle("", displayMode: .inline)
        .toolbar {
            // This is for the 'Plus' button aligned with the system back button.
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if let currentURL = currentURL {
                        print("Current URL: \(currentURL.absoluteString)")
                    }
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
