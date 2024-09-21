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
    @Published var rankingCategories: [RankingCategory] = []
    @Published private(set) var bookCache: [String: Book] = [:]
    
    private let currentFoundBooksSubject = CurrentValueSubject<Int, Never>(0)
    var currentFoundBooksPublisher: AnyPublisher<Int, Never> {
        currentFoundBooksSubject.eraseToAnyPublisher()
    }
    
    private let baseURL = "https://www.bqgda.cc"
    private var cancellables = Set<AnyCancellable>()
    private var webView: WKWebView?
    private var errorTimer: Timer?
    
    override init() {
        super.init()
        setupWebView()
        loadPopularBooks()
        fetchRankings()
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
            self.showError("Invalid search query")
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
        
        // 添加超时处理
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.isLoading == true {
                self?.handleSearchCompletion()
                self?.showError("搜超时，请重试")
            }
        }
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
    
    private func showError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.errorTimer?.invalidate()
            self.errorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.clearError()
            }
        }
    }
    
    private func clearError() {
        DispatchQueue.main.async {
            self.errorMessage = nil
            self.errorTimer?.invalidate()
            self.errorTimer = nil
        }
    }
    
    func clearResults() {
        print("Clearing search results")
        searchResults.removeAll()
        clearError()
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
        // 这里该是从服务器获取热门书籍的逻辑
        // 现在我们使用模拟数据
        popularBooks = [
            Book(title: "开局签到荒古圣体", author: "作者1", coverURL: "https://example.com/cover1.jpg", lastUpdated: "2023-05-01", status: "连中", introduction: "幻 | 简介1", chapters: [], link: ""),
            Book(title: "笑我华夏无神？我开局", author: "作者2", coverURL: "https://example.com/cover2.jpg", lastUpdated: "2023-05-02", status: "连载中", introduction: "玄幻 | 简介2", chapters: [], link: ""),
            Book(title: "诡异怪谈：我的死因不", author: "作者3", coverURL: "https://example.com/cover3.jpg", lastUpdated: "2023-05-03", status: "连载中", introduction: "奇闻怪谈 | 简3", chapters: [], link: ""),
            Book(title: "我从顶流塌房了，系统", author: "作者4", coverURL: "https://example.com/cover4.jpg", lastUpdated: "2023-05-04", status: "连载中", introduction: "都市 | 简介4", chapters: [], link: ""),
            Book(title: "仙逆", author: "作者5", coverURL: "https://example.com/cover5.jpg", lastUpdated: "2023-05-05", status: "已完结", introduction: "仙侠 | 简介5", chapters: [], link: ""),
            Book(title: "完美世界", author: "作者6", coverURL: "https://example.com/cover6.jpg", lastUpdated: "2023-05-06", status: "已完结", introduction: "玄幻 | 简介6", chapters: [], link: ""),
            Book(title: "上门龙婿", author: "作者7", coverURL: "https://example.com/cover7.jpg", lastUpdated: "2023-05-07", status: "连载中", introduction: "都市 | 简介7", chapters: [], link: ""),
            Book(title: "我岳父是李世民", author: "作者8", coverURL: "https://example.com/cover8.jpg", lastUpdated: "2023-05-08", status: "连载中", introduction: "历史 | 简介8", chapters: [], link: ""),
        ]
    }
    
    private func fetchRankings() {
        guard let url = URL(string: "https://www.bqgda.cc/top/") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let html = String(data: data, encoding: .utf8) {
                let rankings = HTMLRankingParser.parseRankings(html: html)
                DispatchQueue.main.async {
                    self.rankingCategories = rankings
                    self.fetchBasicBookInfo(for: rankings)
                }
            }
        }.resume()
    }
    
    private func fetchBasicBookInfo(for categories: [RankingCategory]) {
        for category in categories {
            for book in category.books {
                guard bookCache[book.link] == nil else { continue }
                
                Task {
                    if let url = URL(string: book.link) {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let html = String(data: data, encoding: .utf8) {
                            if let parsedBook = HTMLBookParser.parseBasicBookInfo(html, baseURL: baseURL, bookURL: book.link) {
                                DispatchQueue.main.async {
                                    self.bookCache[book.link] = parsedBook
                                    self.objectWillChange.send()
                                }
                            }
                        }
                    }
                }
            }
        }
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
    @State private var showAllCategories = false
    
    var body: some View {
        NavigationView {
            ScrollView {
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
                        ElegantSearchingView(query: searchText)
                            .padding()
                    } else if let errorMessage = viewModel.errorMessage {
                        ElegantErrorView(message: errorMessage)
                            .padding()
                    } else if !searchText.isEmpty {
                        searchResultsView
                    } else {
                        categoryRankingsView
                        
                        Button(action: {
                            showAllCategories.toggle()
                        }) {
                            Text(showAllCategories ? "收起" : "查看更多分类")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundColor(.blue)
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("书城")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showAllCategories) {
            AllCategoriesView(viewModel: viewModel)
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
    
    private var categoryRankingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(viewModel.rankingCategories.prefix(4), id: \.name) { category in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(category.name)
                            .font(.system(size: 22, weight: .bold, design: .serif))
                        Spacer()
                        NavigationLink(destination: Text("完整\(category.name)榜单")) {
                            Text("查看完整榜单 >")
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(category.books.prefix(5).enumerated()), id: \.element.name) { index, book in
                            RankedBookItemView(viewModel: viewModel, book: book, rank: index + 1)
                            if index < 4 {
                                Divider().padding(.leading, 45)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                if category != viewModel.rankingCategories.prefix(4).last {
                    Divider()
                }
            }
        }
        .padding(.top)
    }
}

struct BookListItemView: View {
    let book: Book
    let rank: Int?
    let isSearchResult: Bool
    
    var category: String {
        book.introduction.components(separatedBy: " | ").first ?? ""
    }
    
    var cleanedIntroduction: String {
        book.introduction.replacingOccurrences(of: "\t", with: "")
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
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                if isSearchResult {
                    Text(cleanedIntroduction)
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

struct RankedBookItemView: View {
    @ObservedObject var viewModel: BookStoreViewModel
    let book: RankedBook
    let rank: Int
    @State private var isShowingBookInfo = false
    
    var body: some View {
        Button(action: {
            isShowingBookInfo = true
        }) {
            HStack(spacing: 15) {
                Text("\(rank)")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(rank <= 3 ? .orange : .gray)
                    .frame(width: 30)
                
                AsyncImage(url: URL(string: viewModel.bookCache[book.link]?.coverURL ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 60, height: 80)
                .cornerRadius(5)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.bookCache[book.link]?.title ?? book.name)
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(viewModel.bookCache[book.link]?.author ?? book.author)
                        .font(.system(size: 14, design: .serif))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $isShowingBookInfo) {
            if let basicInfo = viewModel.bookCache[book.link] {
                BookInfoView(book: basicInfo)
            } else {
                ProgressView("加载中...")
            }
        }
    }
}

struct AllCategoriesView: View {
    @ObservedObject var viewModel: BookStoreViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(viewModel.rankingCategories, id: \.name) { category in
                NavigationLink(destination: CategoryDetailView(category: category, viewModel: viewModel)) {
                    Text(category.name)
                        .font(.system(size: 18, design: .serif))
                }
            }
            .navigationTitle("所有分类")
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct CategoryDetailView: View {
    let category: RankingCategory
    @ObservedObject var viewModel: BookStoreViewModel
    
    var body: some View {
        List(Array(category.books.enumerated()), id: \.element.name) { index, book in
            RankedBookItemView(viewModel: viewModel, book: book, rank: index + 1)
        }
        .navigationTitle(category.name)
    }
}

extension Color {
    static let charcoal = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let tan = Color(red: 0.82, green: 0.71, blue: 0.55)
    static let navy = Color(red: 0.0, green: 0.0, blue: 0.5)
    static let darkRed = Color(red: 0.5, green: 0.0, blue: 0.0)
}
