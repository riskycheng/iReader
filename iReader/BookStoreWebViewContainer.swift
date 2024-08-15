import SwiftUI
import WebKit

struct BookStoreWebViewContainer: View {
    @State private var url: URL?
    @State private var currentURL: URL?
    @Binding var books: [Book]
    var initialURL: URL
    
    var body: some View {
        VStack {
            WebViewContainer(url: $url, currentURL: $currentURL)
                .onAppear {
                    url = initialURL
                }
                .edgesIgnoringSafeArea(.all)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if let currentURL = currentURL {
                        print("Current URL: \(currentURL.absoluteString)")
                        addBookToLibrary(currentURL: currentURL)
                    }
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private func addBookToLibrary(currentURL: URL) {
        let newBook = Book(
            title: "New Book",
            link: currentURL.absoluteString,
            cover: "cover_placeholder", // Update with actual cover if available
            introduction: "This is a newly added book."
        )
        
        books.append(newBook)
    }
}
