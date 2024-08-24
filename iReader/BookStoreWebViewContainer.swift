import SwiftUI
import WebKit

struct BookStoreWebViewContainer: View {
    @Binding var books: [Book]
    @State private var currentURL: URL?
    @State private var isBookURLLoaded = false
    @State private var isChapterURLLoaded = false
    @State private var parsedBook: Book? = nil
    @State private var navigateToReadingView = false
    var initialURL: URL
    
    var body: some View {
        VStack {
            WebViewContainer(url: $currentURL, currentURL: $currentURL, onLoadCompletion: handleURLLoad)
                .onAppear {
                    currentURL = initialURL
                }
                .edgesIgnoringSafeArea(.all)
            
            // NavigationLink to trigger navigation programmatically
            NavigationLink(
                destination: getReadingView(), // Updated destination handling
                isActive: $navigateToReadingView,
                label: { EmptyView() }
            )
            .hidden() // Hide the NavigationLink
        }
        
        
        .toolbar {
            // Reading button on the right
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: navigateToReadingViewAction) {
                    Image(systemName: "book")
                        .foregroundColor(isChapterURLLoaded ? .blue : .gray)
                }
                .disabled(!isChapterURLLoaded)
            }
            
            // Book details button on the right
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if let currentURL = currentURL,
                       let bookLink = getBookLink(from: currentURL.absoluteString) {
                        parseAndAddBookDetails(bookLink: bookLink)
                    }
                }) {
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
    
    // Helper function to get the correct view based on parsing results
    private func getReadingView() -> some View {
        if let book = parsedBook, let chapterLink = currentURL?.absoluteString {
            return AnyView(ReadingView(book: book, chapterLink: chapterLink))
        } else {
            return AnyView(EmptyView())
        }
    }
    
    // Action to navigate to ReadingView with the current chapter link
    private func navigateToReadingViewAction() {
        guard let currentURLString = currentURL?.absoluteString, isChapterURLLoaded else { return }
        
        // Get the corresponding book link for the chapter
        if let bookLinkString = getBookLink(from: currentURLString), let bookLinkURL = URL(string: bookLinkString) {
            parseAndNavigateToReadingView(bookLink: bookLinkURL, chapterLink: currentURLString)
        }
    }
    
    // Helper function to extract the book link from a chapter link
    private func getBookLink(from urlString: String) -> String? {
        if urlString.contains("/books/") && urlString.contains(".html") {
            if let range = urlString.range(of: "/\\d+\\.html$", options: .regularExpression) {
                let bookLink = String(urlString[..<range.lowerBound])
                return bookLink
            }
        }
        return nil
    }
    
    // Action to parse book details from the given book link and navigate to ReadingView
    private func parseAndNavigateToReadingView(bookLink: URL, chapterLink: String) {
        print("Parsing book details for book link: \(bookLink)")
        
        let session = URLSession(configuration: .default)
        session.dataTask(with: bookLink) { data, _, error in
            if let error = error {
                print("Error loading book link: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("Failed to load data from book link: \(bookLink.absoluteString)")
                return
            }
            
            let baseURL = "\(bookLink.scheme ?? "https")://\(bookLink.host ?? "")"
            print("Parsing content from base URL: \(baseURL)")
            
            if let parsedBook = HTMLBookParser.parseHTML(String(data: data, encoding: .utf8) ?? "", baseURL: baseURL) {
                DispatchQueue.main.async {
                    self.parsedBook = parsedBook
                    self.navigateToReadingView = true
                    print("Navigating to ReadingView with parsed book: \(parsedBook.title), chapter link: \(chapterLink)")
                }
            } else {
                print("Failed to parse the content from book link: \(bookLink.absoluteString)")
            }
        }.resume()
    }
    
    // Action to parse book details from the given book link
    private func parseAndAddBookDetails(bookLink: String) {
        guard let url = URL(string: bookLink) else { return }
        print("Initiating parsing for book link: \(bookLink)")
        
        let session = URLSession(configuration: .default)
        session.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Error loading URL: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("Failed to load data from URL: \(bookLink)")
                return
            }
            
            let baseURL = "\(url.scheme ?? "https")://\(url.host ?? "")"
            print("Parsing content from base URL: \(baseURL)")

            if let parsedBook = HTMLBookParser.parseHTML(String(data: data, encoding: .utf8) ?? "", baseURL: baseURL) {
                DispatchQueue.main.async {
                    var bookWithLink = parsedBook
                    bookWithLink.link = bookLink
                    
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
                print("Failed to parse the content from URL: \(bookLink)")
            }
        }.resume()
    }
}
