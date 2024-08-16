import SwiftUI
import WebKit

struct BookStoreWebViewContainer: View {
    @Binding var books: [Book]
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
        .toolbar {
            // 'Plus' button for adding a new book with minimal details
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: addBookWithMinimalDetails) {
                    Image(systemName: "plus")
                }
            }
            
            // Button to parse and add book details using HTMLBookParser
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: parseAndAddBookDetails) {
                    Image(systemName: "text.book.closed")
                }
            }
        }
    }
    
    // Action to add a book with minimal details
    private func addBookWithMinimalDetails() {
        if let currentURL = currentURL {
            print("Current URL: \(currentURL.absoluteString)")
            
            // Create a new book with basic details
            let newBook = Book(
                title: "New Book",
                author: "Unknown Author",
                coverURL: "", // Placeholder cover URL
                lastUpdated: "N/A",
                status: "Unknown",
                introduction: "Newly added book from the web",
                chapters: [], // Empty chapters array
                link: currentURL.absoluteString // Include the link property
            )
            
            // Append the new book to the books list
            books.append(newBook)
            print("Added new book: \(newBook.title) to the library.")
        }
    }
    
    // Action to parse book details from the current URL
    private func parseAndAddBookDetails() {
        guard let currentURL = currentURL else { return }
        print("Initiating parsing for URL: \(currentURL.absoluteString)")
        
        let session = URLSession(configuration: .default)
        
        session.dataTask(with: currentURL) { data, response, error in
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

            if let htmlString = String(data: data, encoding: .utf8) {
                let parser = HTMLBookParser()
                
                if let parsedBook = HTMLBookParser.parseHTML(htmlString) {
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
            } else {
                print("Failed to convert data to a string")
            }
        }.resume()
    }
}
