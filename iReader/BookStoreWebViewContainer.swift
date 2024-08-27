import SwiftUI
import WebKit

struct BookStoreWebViewContainer: View {
    @Binding var books: [Book]
    @State private var currentURL: URL?
    @State private var isBookURLLoaded = false
    @State private var isChapterURLLoaded = false
    @State private var parsedBook: Book? = nil
    @State private var navigateToReadingView = false
    @State private var isLoadingBook = false // State to track loading status
    var initialURL: URL
    
    var body: some View {
        ZStack {
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
            
            // Dim the background when the loading dialog is shown
            if isLoadingBook {
                Color.black.opacity(0.4)
                    .ignoresSafeArea() // Dim the background
                
                VStack {
                    ProgressView("书籍解析中")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.bottom, 10)
                    Text("请稍候, 马上就好...")
                        .font(.headline)
                        .foregroundColor(.blue) // Change text color to blue
                }
                .padding()
                .background(Color.white) // Non-transparent white background for the dialog
                .cornerRadius(15)
                .shadow(radius: 10)
                .frame(width: 250, height: 150)
            }
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
            return AnyView(ReadingView(book: book, chapterLink: chapterLink, isReadingViewActive: .constant(true)))
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
        
        isLoadingBook = true // Start showing loading indicator
        
        let session = URLSession(configuration: .default)
        session.dataTask(with: bookLink) { data, _, error in
            if let error = error {
                print("Error loading book link: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingBook = false // Hide loading indicator
                }
                return
            }
            
            guard let data = data else {
                print("Failed to load data from book link: \(bookLink.absoluteString)")
                DispatchQueue.main.async {
                    self.isLoadingBook = false // Hide loading indicator
                }
                return
            }
            
            let baseURL = "\(bookLink.scheme ?? "https")://\(bookLink.host ?? "")"
            print("Parsing content from base URL: \(baseURL)")
            
            if let parsedBook = HTMLBookParser.parseHTML(String(data: data, encoding: .utf8) ?? "", baseURL: baseURL) {
                DispatchQueue.main.async {
                    self.isLoadingBook = false // Hide loading indicator
                    self.parsedBook = parsedBook
                    self.navigateToReadingView = true
                    print("Navigating to ReadingView with parsed book: \(parsedBook.title), chapter link: \(chapterLink)")
                }
            } else {
                print("Failed to parse the content from book link: \(bookLink.absoluteString)")
                DispatchQueue.main.async {
                    self.isLoadingBook = false // Hide loading indicator
                }
            }
        }.resume()
    }
    
    // Action to parse book details from the given book link
    private func parseAndAddBookDetails(bookLink: String) {
        guard let url = URL(string: bookLink) else { return }
        print("Initiating parsing for book link: \(bookLink)")
        
        isLoadingBook = true // Start showing loading indicator
        
        let session = URLSession(configuration: .default)
        session.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Error loading URL: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingBook = false // Hide loading indicator
                }
                return
            }
            
            guard let data = data else {
                print("Failed to load data from URL: \(bookLink)")
                DispatchQueue.main.async {
                    self.isLoadingBook = false // Hide loading indicator
                }
                return
            }
            
            let baseURL = "\(url.scheme ?? "https")://\(url.host ?? "")"
            print("Parsing content from base URL: \(baseURL)")

            if let parsedBook = HTMLBookParser.parseHTML(String(data: data, encoding: .utf8) ?? "", baseURL: baseURL) {
                DispatchQueue.main.async {
                    self.isLoadingBook = false // Hide loading indicator
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
                DispatchQueue.main.async {
                    self.isLoadingBook = false // Hide loading indicator
                }
            }
        }.resume()
    }
}
