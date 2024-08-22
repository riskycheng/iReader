import SwiftUI
import WebKit

struct BookStoreWebViewContainer: View {
    @Binding var books: [Book]
    @State private var currentURL: URL?
    @State private var isBookURLLoaded = false
    @State private var isChapterURLLoaded = false
    var initialURL: URL
    
    var body: some View {
        VStack {
            WebViewContainer(url: $currentURL, currentURL: $currentURL, onLoadCompletion: handleURLLoad)
                .onAppear {
                    currentURL = initialURL
                }
                .edgesIgnoringSafeArea(.all)
        }
        .toolbar {
            // 'Reading' button for navigating to ReadingView with the current chapter link
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: navigateToReadingView) {
                    Image(systemName: "book")
                        .foregroundColor(isChapterURLLoaded ? .blue : .gray)
                }
                .disabled(!isChapterURLLoaded)
            }
            
            // 'text.book.closed' button for parsing and adding book details using HTMLBookParser
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: parseAndAddBookDetails) {
                    Image(systemName: "text.book.closed")
                        .foregroundColor(isBookURLLoaded ? .blue : .gray)
                }
                .disabled(!isBookURLLoaded)
            }
        }
    }
    
    // Handle URL load completion and check if it's a book or chapter link
    private func handleURLLoad(url: URL?) {
        guard let url = url else { return }
        
        let urlString = url.absoluteString
        if urlString.contains("/books/") && urlString.hasSuffix("/") {
            // Specific book link detected
            isBookURLLoaded = true
            isChapterURLLoaded = false
        } else if urlString.contains("/books/") && urlString.contains(".html") {
            // Specific chapter link detected
            isChapterURLLoaded = true
            isBookURLLoaded = false
        } else {
            // Reset states for non-book/chapter URLs
            isBookURLLoaded = false
            isChapterURLLoaded = false
        }
    }
    
    // Action to navigate to ReadingView with the current chapter link
    private func navigateToReadingView() {
        guard let currentURL = currentURL?.absoluteString, isChapterURLLoaded else { return }
        
        // Find the corresponding book
        if let book = books.first(where: { currentURL.contains($0.link) }) {
            // Navigate to ReadingView (using NavigationLink or presenting the view)
            // Replace with your navigation logic
            print("Navigating to ReadingView with chapter link: \(currentURL)")
            // Implement the actual navigation here
        }
    }
    
    // Action to parse book details from the current URL
    private func parseAndAddBookDetails() {
        guard let currentURL = currentURL else { return }
        print("Initiating parsing for URL: \(currentURL.absoluteString)")
        
        let session = URLSession(configuration: .default)
        session.dataTask(with: currentURL) { data, _, error in
            if let error = error {
                print("Error loading URL: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("Failed to load data from URL: \(currentURL.absoluteString)")
                return
            }
            
            let baseURL = "\(currentURL.scheme ?? "https")://\(currentURL.host ?? "")"
            print("Parsing content from base URL: \(baseURL)")

            if let parsedBook = HTMLBookParser.parseHTML(String(data: data, encoding: .utf8) ?? "", baseURL: baseURL) {
                DispatchQueue.main.async {
                    var bookWithLink = parsedBook
                    bookWithLink.link = currentURL.absoluteString // Assign the correct link
                    
                    books.append(bookWithLink)
                    print("Parsed book details successfully:")
                    print("Title: \(bookWithLink.title)")
                    print("Author: \(bookWithLink.author)")
                    print("Cover URL: \(bookWithLink.coverURL)")
                    print("Updated Date: \(bookWithLink.lastUpdated)")
                    print("Status: \(bookWithLink.status)")
                    print("Chapters count: \(bookWithLink.chapters.count)")
                    print("Introduction: \(bookWithLink.introduction)")
                }
            } else {
                print("Failed to parse the content from URL: \(currentURL.absoluteString)")
            }
        }.resume()
    }
}
