import SwiftUI
import Combine
import WebKit

struct BookStoreView: View {
    @State private var searchText = ""
    @StateObject private var viewModel = BookStoreViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, onSubmit: {
                    if !searchText.isEmpty {
                        viewModel.search(query: searchText)
                    }
                })
                
                if viewModel.isLoading {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                } else if viewModel.searchResults.isEmpty {
                    Text("No results found")
                        .foregroundColor(.gray)
                } else {
                    List(viewModel.searchResults) { book in
                        BookSearchResultView(book: book)
                    }
                }
            }
            .navigationTitle("书城")
        }
    }
}


struct SearchBar: View {
    @Binding var text: String
    var onSubmit: () -> Void
    
    var body: some View {
        HStack {
            TextField("搜索", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit(onSubmit)
            
            Button(action: onSubmit) {
                Image(systemName: "magnifyingglass")
            }
        }
        .padding()
    }
}


struct BookSearchResultView: View {
    let book: Book
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: book.coverURL)) { image in
                image.resizable()
            } placeholder: {
                Color.gray
            }
            .frame(width: 80, height: 120)
            .cornerRadius(5)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(.headline)
                    .foregroundColor(.blue)
                Text(book.author)
                    .font(.subheadline)
                Text(book.introduction)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.secondary)
                HStack {
                    Text("说说520等 共2个书源")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("查看全部 >") {
                        // Action to view all details
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            VStack {
                Button(action: {
                    // Action for 说说520 button
                }) {
                    Text("说说520")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(15)
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }
}
    
class BookStoreViewModel: NSObject, ObservableObject {
    @Published var searchResults: [Book] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    private let baseURL = "https://www.bqgda.cc"
    private var cancellables = Set<AnyCancellable>()
    private var webView: WKWebView?
    
    override init() {
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "bookSearchHandler")
        webView = WKWebView(frame: .zero, configuration: config)
        
        // Add a script to capture the full HTML content
        let script = WKUserScript(source: """
            function captureHTML() {
                window.webkit.messageHandlers.bookSearchHandler.postMessage(document.documentElement.outerHTML);
            }
            setTimeout(captureHTML, 2000);  // Capture HTML after 2 seconds
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
    }
    
    func search(query: String) {
        print("Starting search for query: \(query)")
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/s?q=\(encodedQuery)") else {
            print("Failed to create URL for query: \(query)")
            self.errorMessage = "Invalid search query"
            return
        }
        
        isLoading = true
        errorMessage = nil
        searchResults.removeAll()
        
        let request = URLRequest(url: url)
        webView?.load(request)
        print("WebView loading URL: \(url)")
    }
    
    private func handleSearchResults(_ results: [Book]) {
        DispatchQueue.main.async {
            self.searchResults = results
            self.isLoading = false
            print("Search completed. Found \(results.count) books.")
        }
    }
    
    func clearResults() {
        print("Clearing search results")
        searchResults.removeAll()
        errorMessage = nil
        isLoading = false
        cancellables.removeAll()
    }
}

extension BookStoreViewModel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "bookSearchHandler", let body = message.body as? String {
            print("Received message from WebView. HTML length: \(body.count)")
            let books = HTMLSearchParser.parseSearchResults(html: body, baseURL: baseURL)
            handleSearchResults(books)
        }
    }
}

    
    struct BookSearchResult {
        let title: String
        let author: String
        let coverURL: String
    }
    
    struct FeaturedItem: View {
        let title: String
        let subtitle: String
        let color: Color
        
        var body: some View {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(color)
                    .frame(height: 120)
                    .cornerRadius(10)
                
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
            }
        }
    }
    
    struct CategoryItem: View {
        let title: String
        let color: Color
        
        var body: some View {
            VStack {
                Rectangle()
                    .fill(color)
                    .frame(height: 100)
                    .cornerRadius(10)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
    }
    
    
    
    
struct BookStoreView_Previews: PreviewProvider {
    static var previews: some View {
        BookStoreView()
    }
}


extension Color {
    static let charcoal = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let tan = Color(red: 0.82, green: 0.71, blue: 0.55)
    static let navy = Color(red: 0.0, green: 0.0, blue: 0.5)
    static let darkRed = Color(red: 0.5, green: 0.0, blue: 0.0)
}
