import SwiftUI
import Combine
import WebKit

class BookStoreViewModel: NSObject, ObservableObject {
    @Published var searchResults: [Book] = []
    @Published var popularBooks: [Book] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var searchCompleted: Bool = false
    @Published var searchProgress: Double = 0
    
    private let currentFoundBooksSubject = CurrentValueSubject<Int, Never>(0)
    var currentFoundBooksPublisher: AnyPublisher<Int, Never> {
        currentFoundBooksSubject.eraseToAnyPublisher()
    }
    
    private let baseURL = "https://www.bqgda.cc"
    private var cancellables = Set<AnyCancellable>()
    private var webView: WKWebView?
    
    override init() {
        super.init()
        setupWebView()
        loadPopularBooks()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "bookSearchHandler")
        webView = WKWebView(frame: .zero, configuration: config)
        
        let script = WKUserScript(source: """
            function captureHTML() {
                window.webkit.messageHandlers.bookSearchHandler.postMessage(document.documentElement.outerHTML);
            }
            setTimeout(captureHTML, 2000);
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
        searchCompleted = false
        errorMessage = nil
        searchResults.removeAll()
        searchProgress = 0
        currentFoundBooksSubject.send(0)
        
        let request = URLRequest(url: url)
        self.webView?.load(request)
        print("WebView loading URL: \(url)")
    }
    
    private func updateSearchResults(_ books: [Book]) {
        DispatchQueue.main.async {
            self.searchResults = books
            self.currentFoundBooksSubject.send(books.count)
            self.searchProgress = min(Double(books.count) / 100.0, 1.0)
            print("Updated search results on main thread. Current count: \(books.count)")
        }
    }
    
    private func handleSearchCompletion() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.searchCompleted = true
            self.searchProgress = 1.0
            print("Search completed. Final count: \(self.currentFoundBooksSubject.value)")
        }
    }
    
    func clearResults() {
        print("Clearing search results")
        searchResults.removeAll()
        errorMessage = nil
        isLoading = false
        searchCompleted = false
        searchProgress = 0
        currentFoundBooksSubject.send(0)
        cancellables.removeAll()
    }
    
    func parseFullBookInfo(for book: Book, completion: @escaping (Result<Book, Error>) -> Void) {
            guard let url = URL(string: book.link) else {
                completion(.failure(NSError(domain: "InvalidURL", code: 0, userInfo: nil)))
                return
            }
            
            Task {
                do {
                    let parsedBook = try await Book.parse(from: url, baseURL: baseURL)
                    DispatchQueue.main.async {
                        completion(.success(parsedBook))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    
    private func loadPopularBooks() {
        // 这里应该是从服务器获取热门书籍的逻辑
        // 现在我们使用模拟数据
        popularBooks = [
            Book(title: "开局签到荒古圣体", author: "作者1", coverURL: "https://example.com/cover1.jpg", lastUpdated: "2023-05-01", status: "连载中", introduction: "幻 | 简介1", chapters: [], link: ""),
            Book(title: "笑我华夏无神？我开局", author: "作者2", coverURL: "https://example.com/cover2.jpg", lastUpdated: "2023-05-02", status: "连载中", introduction: "玄幻 | 简介2", chapters: [], link: ""),
            Book(title: "诡异怪谈：我的死因不", author: "作者3", coverURL: "https://example.com/cover3.jpg", lastUpdated: "2023-05-03", status: "连载中", introduction: "奇闻怪谈 | 简3", chapters: [], link: ""),
            Book(title: "我从顶流塌房了，系统", author: "作者4", coverURL: "https://example.com/cover4.jpg", lastUpdated: "2023-05-04", status: "连载中", introduction: "都市 | 简介4", chapters: [], link: ""),
            Book(title: "仙逆", author: "作者5", coverURL: "https://example.com/cover5.jpg", lastUpdated: "2023-05-05", status: "已完结", introduction: "仙侠 | 简介5", chapters: [], link: ""),
            Book(title: "完美世界", author: "作者6", coverURL: "https://example.com/cover6.jpg", lastUpdated: "2023-05-06", status: "已完结", introduction: "玄幻 | 简介6", chapters: [], link: ""),
            Book(title: "上门龙婿", author: "作者7", coverURL: "https://example.com/cover7.jpg", lastUpdated: "2023-05-07", status: "连载中", introduction: "都市 | 简介7", chapters: [], link: ""),
            Book(title: "我岳父是李世民", author: "作者8", coverURL: "https://example.com/cover8.jpg", lastUpdated: "2023-05-08", status: "连载中", introduction: "历史 | 简介8", chapters: [], link: ""),
        ]
    }
}

extension BookStoreViewModel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "bookSearchHandler", let body = message.body as? String {
            print("Received message from WebView. HTML length: \(body.count)")
            HTMLSearchParser.parseSearchResults(html: body, baseURL: baseURL) { [weak self] books in
                self?.updateSearchResults(books)
            } completion: { [weak self] in
                self?.handleSearchCompletion()
            }
        }
    }
}

struct BookStoreView: View {
    @StateObject private var viewModel = BookStoreViewModel()
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(text: $searchText, onSubmit: {
                    if !searchText.isEmpty {
                        viewModel.search(query: searchText)
                        isSearchFocused = false
                    }
                }, onClear: {
                    searchText = ""
                    isSearchFocused = false
                    viewModel.clearResults()
                })
                .focused($isSearchFocused)
                .padding(.horizontal)
                .padding(.top)
                
                if viewModel.isLoading {
                    Spacer()
                    ElegantSearchingView(query: searchText)
                    Spacer()
                } else if let errorMessage = viewModel.errorMessage {
                    Spacer()
                    ElegantErrorView(message: errorMessage)
                    Spacer()
                } else if !searchText.isEmpty {
                    searchResultsView
                } else {
                    popularBooksView
                }
            }
            .navigationTitle("书城")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults) { book in
                    NavigationLink(destination: BookInfoView(book: book)) {
                        BookListItemView(book: book, rank: nil, isSearchResult: true)
                    }
                    Divider()
                }
            }
        }
    }
    
    private var popularBooksView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("搜索发现")
                        .font(.headline)
                    Spacer()
                    Text("热搜榜 >")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top)
                
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.popularBooks.enumerated()), id: \.element.id) { index, book in
                        NavigationLink(destination: BookInfoView(book: book)) {
                            BookListItemView(book: book, rank: index + 1, isSearchResult: false)
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

struct BookListItemView: View {
    let book: Book
    let rank: Int?
    let isSearchResult: Bool
    
    var category: String {
        book.introduction.components(separatedBy: " | ").first ?? ""
    }
    
    var body: some View {
        HStack(spacing: 15) {
            if let rank = rank {
                Text("\(rank)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(rank <= 3 ? .orange : .gray)
                    .frame(width: 20)
            }
            
            AsyncImage(url: URL(string: book.coverURL)) { image in
                image.resizable()
            } placeholder: {
                Color.gray
            }
            .frame(width: 60, height: 80)
            .cornerRadius(5)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                Text(book.author)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                if isSearchResult {
                    Text(book.introduction)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                } else {
                    Text(category)
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(Color.white)
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSubmit: () -> Void
    var onClear: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜索", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit(onSubmit)
            
            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ElegantSearchingView: View {
    let query: String
    
    @State private var animationAmount: CGFloat = 1
    
    var body: some View {
        VStack(spacing: 20) {
            Text("正在搜索")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("\"\(query)\"")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(height: 30)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .foregroundColor(.blue)
                    .rotationEffect(Angle(degrees: animationAmount))
                    .frame(width: 100, height: 100)
                    .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: animationAmount)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
        }
        .frame(width: 250)
        .padding(25)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onAppear {
            animationAmount = 360
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
