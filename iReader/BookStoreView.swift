import SwiftUI
import Combine
import WebKit

class BookStoreViewModel: NSObject, ObservableObject {
    // 添加网站配置常量
    private static let baseDomain = "www.qu08.cc"
    private static let baseURL = "https://\(baseDomain)"
    private static let searchPath = "/s"
    private static let rankingPath = "/top"
    
    @Published var searchResults: [Book] = []
    @Published var popularBooks: [Book] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var searchCompleted: Bool = false
    @Published var searchProgress: Double = 0
    @Published var rankingCategories: [RankingCategory] = []
    @Published private(set) var bookCache: [String: BasicBookInfo] = [:]
    private var imageCache: NSCache<NSString, UIImage> = NSCache()
    @Published var isSearching: Bool = false
    private var searchTimer: Timer?
    private var searchAttempts: Int = 0
    private let maxSearchAttempts = 10
    
    private let currentFoundBooksSubject = CurrentValueSubject<Int, Never>(0)
    var currentFoundBooksPublisher: AnyPublisher<Int, Never> {
        currentFoundBooksSubject.eraseToAnyPublisher()
    }
    
    private var baseURL: String {
        BookStoreViewModel.baseURL
    }
    private var cancellables = Set<AnyCancellable>()
    private var webView: WKWebView?
    private var errorTimer: Timer?
    private var loadingTasks: [UUID: Task<Void, Never>] = [:]
    private let taskQueue = DispatchQueue(label: "com.iReader.taskQueue")
    private var isPaused = false
    @Published var isInitialLoading = true
    private var imageLoadingTasks: [String: Task<Void, Never>] = [:]
    
    @Published private var loadedCategories: Set<String> = []
    private var loadedCovers: Set<String> = []
    
    override init() {
        super.init()
        setupWebView()
        loadPlaceholderData()
    }
    
    func loadInitialData() {
        isInitialLoading = true
        loadPopularBooks()
        fetchInitialRankings()
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
        print("开始搜索: \(query)")
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(BookStoreViewModel.baseURL)\(BookStoreViewModel.searchPath)?q=\(encodedQuery)") else {
            print("无效的搜索查询: \(query)")
            self.showError("无效的搜索查询")
            return
        }
        
        isLoading = true
        isSearching = true
        searchCompleted = false
        errorMessage = nil
        searchResults.removeAll()
        searchProgress = 0
        currentFoundBooksSubject.send(0)
        searchAttempts = 0
        
        let request = URLRequest(url: url)
        self.webView?.load(request)
        print("WebView 加载 URL: \(url)")
        
        // 设置定时器以定期检查搜索结果
        searchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkSearchResults()
        }
    }
    
    private func checkSearchResults() {
        searchAttempts += 1
        
        if searchAttempts >= maxSearchAttempts {
            handleSearchCompletion()
            return
        }
        
        webView?.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            if let html = result as? String {
                HTMLSearchParser.parseSearchResults(html: html, baseURL: self?.baseURL ?? "") { books in
                    self?.updateSearchResults(books)
                } completion: {
                    if self?.searchResults.isEmpty == false {
                        self?.handleSearchCompletion()
                    }
                }
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
            self.isSearching = false
            self.searchCompleted = true
            self.searchProgress = 1.0
            self.searchTimer?.invalidate()
            self.searchTimer = nil
            print("搜索完成。最终结果数: \(self.currentFoundBooksSubject.value)")
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
        clearLoadingState()
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
        // 这�������������������������������是从服务器获取热的辑
        // 现在我们使用模拟数据
        popularBooks = [
            Book(title: "开局到荒古圣体", author: "作者1", coverURL: "https://example.com/cover1.jpg", lastUpdated: "2023-05-01", status: "连中", introduction: "幻 | 简介1", chapters: [], link: ""),
            Book(title: "笑我华夏无神？我开���", author: "作者2", coverURL: "https://example.com/cover2.jpg", lastUpdated: "2023-05-02", status: "连载中", introduction: "玄幻 | 简介2", chapters: [], link: ""),
            Book(title: "诡异怪谈：我的死因不", author: "作者3", coverURL: "https://example.com/cover3.jpg", lastUpdated: "2023-05-03", status: "连载中", introduction: "奇闻怪谈 | 简3", chapters: [], link: ""),
            Book(title: "我从顶流塌房了，系统", author: "作者4", coverURL: "https://example.com/cover4.jpg", lastUpdated: "2023-05-04", status: "连载中", introduction: "都市 | 简介4", chapters: [], link: ""),
            Book(title: "仙逆", author: "作者5", coverURL: "https://example.com/cover5.jpg", lastUpdated: "2023-05-05", status: "已完结", introduction: "仙侠 | 简介5", chapters: [], link: ""),
            Book(title: "完���世���", author: "��者6", coverURL: "https://example.com/cover6.jpg", lastUpdated: "2023-05-06", status: "已完结", introduction: "玄幻 | 简介6", chapters: [], link: ""),
            Book(title: "上门龙婿", author: "作者7", coverURL: "https://example.com/cover7.jpg", lastUpdated: "2023-05-07", status: "连中", introduction: "都市 | 7", chapters: [], link: ""),
            Book(title: "我岳父是李世民", author: "作者8", coverURL: "https://example.com/cover8.jpg", lastUpdated: "2023-05-08", status: "连载中", introduction: "历史 | 简介8", chapters: [], link: ""),
        ]
    }
    
    func fetchInitialRankings() {
        guard let url = URL(string: "\(BookStoreViewModel.baseURL)\(BookStoreViewModel.rankingPath)/") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let html = String(data: data, encoding: .utf8) {
                let rankings = HTMLRankingParser.parseRankings(html: html)
                DispatchQueue.main.async {
                    self.rankingCategories = rankings
                    self.fetchTopBooksForInitialCategories()
                }
            }
        }.resume()
    }
    
    private func fetchTopBooksForInitialCategories() {
        let categoriesToFetch = Array(rankingCategories.prefix(4))
        for category in categoriesToFetch {
            fetchTopBooksForCategory(category, count: 5)
        }
    }
    
    func fetchTopBooksForCategory(_ category: RankingCategory, count: Int) {
        guard !isPaused else { return }
        
        // 添加安全检查
        guard !category.books.isEmpty else {
            print("Warning: Attempting to fetch books for empty category: \(category.name)")
            return
        }
        
        let taskId = UUID()
        let task = Task {
            // 使用安全的数组访问
            let booksToFetch = category.books.prefix(count)
            guard !booksToFetch.isEmpty else {
                print("Warning: No books to fetch for category: \(category.name)")
                return
            }
            
            var loadedCount = 0
            
            for book in booksToFetch {
                guard !Task.isCancelled && !isPaused else { break }
                
                // 添加额外的安全检查
                guard !book.link.isEmpty else {
                    print("Warning: Empty book link encountered")
                    continue
                }
                
                await loadBasicBookInfo(for: book)
                loadedCount += 1
                
                // 当加载了足够的书籍信息后，标记该分类为已加载
                if loadedCount >= min(5, count) {
                    await MainActor.run {
                        markCategoryAsLoaded(category)
                    }
                }
            }
            
            await MainActor.run {
                removeTask(id: taskId)
            }
        }
        
        addTask(task, id: taskId)
    }
    
    func preloadTopBooksForCategory(_ category: RankingCategory) {
        fetchTopBooksForCategory(category, count: 20)
    }
    
    internal func loadBasicBookInfo(for book: RankedBook) {
        // 添加安全检查
        guard !isPaused,
              !book.link.isEmpty,
              bookCache[book.link] == nil else { return }
        
        let taskId = UUID()
        let task = Task {
            guard !Task.isCancelled && !isPaused else { return }
            
            let bookURL = book.link.starts(with: "http") ? book.link : "\(baseURL)\(book.link)"
            guard let url = URL(string: bookURL) else {
                print("Warning: Invalid URL for book: \(book.name)")
                return
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled && !isPaused else { return }
                
                if let html = String(data: data, encoding: .utf8) {
                    if let parsedBook = HTMLBookParser.parseBasicBookInfo(html, baseURL: baseURL, bookURL: book.link) {
                        await MainActor.run {
                            let fullCoverURL = parsedBook.coverURL.starts(with: "http") ? 
                                parsedBook.coverURL : "\(self.baseURL)\(parsedBook.coverURL)"
                            
                            // 放宽条件：只要有标题或作者就认为是有效数据
                            if !parsedBook.title.isEmpty || !parsedBook.author.isEmpty {
                                self.bookCache[book.link] = BasicBookInfo(
                                    title: parsedBook.title,
                                    author: parsedBook.author,
                                    introduction: parsedBook.introduction,
                                    coverURL: fullCoverURL
                                )
                                self.objectWillChange.send()
                                
                                // 立即检查是否应该标�����分类为已加载
                                if let category = self.rankingCategories.first(where: { $0.books.contains { $0.link == book.link } }) {
                                    self.markCategoryAsLoaded(category)
                                }
                                
                                // 开始加载封面图片
                                if !self.loadedCovers.contains(book.link) {
                                    self.loadBookCover(for: book)
                                }
                            }
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("Error loading basic book info: \(error)")
                }
            }
            
            await MainActor.run {
                removeTask(id: taskId)
            }
        }
        
        addTask(task, id: taskId)
    }
    
    private func preloadImage(for urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    ImageCache.shared.setImage(image, for: urlString)
                }
            }
        }.resume()
    }
    
    func getCachedImage(for url: String) -> UIImage? {
        return ImageCache.shared.image(for: url)
    }
    
    func downloadAndCacheImage(for url: String, completion: @escaping (UIImage?) -> Void) {
        if let cachedImage = getCachedImage(for: url) {
            completion(cachedImage)
            return
        }
        
        guard let imageURL = URL(string: url) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            ImageCache.shared.setImage(image, for: url)
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }

    func loadFullBookInfo(for book: RankedBook, completion: @escaping (Book?) -> Void) {
        guard let url = URL(string: book.link.starts(with: "http") ? book.link : "\(baseURL)\(book.link)") else {
            completion(nil)
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let html = String(data: data, encoding: .utf8) {
                    if let parsedBook = HTMLBookParser.parseHTML(html, baseURL: baseURL, bookURL: book.link) {
                        DispatchQueue.main.async {
                            completion(parsedBook)
                        }
                    }
                }
            } catch {
                print("加载完整书籍信时出错：\(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    func preloadImages() {
        for category in rankingCategories.prefix(4) {
            for book in category.books.prefix(5) {
                if let coverURL = bookCache[book.link]?.coverURL {
                    downloadAndCacheImage(for: coverURL) { _ in }
                }
            }
        }
    }
    
    func pauseLoading() {
        isPaused = true
        taskQueue.async {
            self.loadingTasks.values.forEach { $0.cancel() }
            self.loadingTasks.removeAll()
        }
    }
    
    func resumeLoading() {
        isPaused = false
        if rankingCategories.isEmpty {
            fetchInitialRankings()
        }
    }
    
    deinit {
        pauseLoading()
    }
    
    // 添加任务管理的辅助方法
    private func addTask(_ task: Task<Void, Never>, id: UUID) {
        taskQueue.async {
            self.loadingTasks[id] = task
        }
    }
    
    private func removeTask(id: UUID) {
        taskQueue.async {
            self.loadingTasks.removeValue(forKey: id)
        }
    }
    
    private func loadPlaceholderData() {
        popularBooks = Array(repeating: Book.placeholder, count: 8)
        rankingCategories = Array(repeating: RankingCategory(
            name: "", 
            books: Array(repeating: RankedBook(
                name: "", 
                author: "", 
                link: "",
                coverURL: ""
            ), count: 5)
        ), count: 4)
    }
    
    func pauseImageLoading() {
        imageLoadingTasks.values.forEach { $0.cancel() }
        imageLoadingTasks.removeAll()
    }
    
    func resumeImageLoading() {
        for category in rankingCategories.prefix(4) {
            for book in category.books.prefix(5) {
                if let basicInfo = bookCache[book.link] {
                    // 如果基本信息已存在但封面未加载，重新加载封面
                    if !loadedCovers.contains(book.link) {
                        loadBookCover(for: book)
                    }
                } else {
                    // 如果基本信息不存在，重新加载基本信息
                    loadBasicBookInfo(for: book)
                }
            }
        }
    }
    
    private func loadBookCover(for book: RankedBook) {
        guard let coverURL = bookCache[book.link]?.coverURL,
              !loadedCovers.contains(book.link) else { return }
        
        // 如果已经有正在进行的任务，先取消
        imageLoadingTasks[book.link]?.cancel()
        
        let task = Task {
            guard !Task.isCancelled else { return }
            if await loadAndCacheImage(from: coverURL) {
                await MainActor.run {
                    loadedCovers.insert(book.link)
                }
            }
        }
        imageLoadingTasks[book.link] = task
    }
    
    private func loadAndCacheImage(from urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    ImageCache.shared.setImage(image, for: urlString)
                }
                return true
            }
        } catch {
            print("Error loading image: \(error)")
        }
        return false
    }
    
    // 检查分类是否已加载完成
    func isCategoryLoaded(_ category: RankingCategory) -> Bool {
        return loadedCategories.contains(category.name)
    }
    
    // 在成功加载分类数据后调用此方法
    private func markCategoryAsLoaded(_ category: RankingCategory) {
        Task { @MainActor in
            // 检查前5本书中是否至少有3本已加载基本信息
            let loadedBooksCount = category.books.prefix(5).filter { book in
                if let basicInfo = bookCache[book.link] {
                    return !basicInfo.title.isEmpty && !basicInfo.author.isEmpty
                }
                return false
            }.count
            
            // 如果至少有3本书加载了基本信息，就标记为已加载
            if loadedBooksCount >= 3 {
                loadedCategories.insert(category.name)
                objectWillChange.send()
            }
        }
    }
    
    func clearLoadingState() {
        // 只清除图片加载任务，保留已加载的数据
        imageLoadingTasks.removeAll()
    }
    
    // 添加一个方法用于清除所有缓存（在需要完全重置时使用）
    func clearAllCache() {
        loadedCovers.removeAll()
        imageLoadingTasks.removeAll()
        bookCache.removeAll()
        loadedCategories.removeAll()
    }
    
    func pauseAllLoading() {
        // 暂停所有加载任务
        isPaused = true
        pauseImageLoading()
        pauseLoading()
        
        // 取消所有正在进行的网络请求
        loadingTasks.values.forEach { $0.cancel() }
        imageLoadingTasks.values.forEach { $0.cancel() }
        
        // 清理任务队列
        taskQueue.async {
            self.loadingTasks.removeAll()
            self.imageLoadingTasks.removeAll()
        }
    }
    
    func resumeAllLoading() {
        // 恢复所有加载任务
        isPaused = false
        resumeImageLoading()
        resumeLoading()
        
        // 重新加载未完成的分类数据
        for category in rankingCategories where !loadedCategories.contains(category.name) {
            fetchTopBooksForCategory(category, count: 5)
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
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool
    @State private var showAllCategories = false
    @State private var hasInitialized = false
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var isInitialLoading = true

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        SearchBar(
                            text: $searchText,
                            isSearching: $isSearching,
                            onSubmit: {
                                if !searchText.isEmpty {
                                    viewModel.search(query: searchText)
                                    isSearchFocused = false
                                    isSearching = true
                                }
                            },
                            onClear: {
                                searchText = ""
                                isSearchFocused = false
                                isSearching = false
                                viewModel.clearResults()
                            }
                        )
                        .padding(.horizontal)
                        .padding(.top)
                        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
                        
                        if !hasInitialized {
                            categoryRankingsPlaceholder
                        } else if viewModel.isLoading {
                            ElegantSearchingView(query: searchText)
                                .padding()
                        } else if let errorMessage = viewModel.errorMessage {
                            ElegantErrorView(message: errorMessage)
                                .padding()
                        } else if !searchText.isEmpty {
                            if viewModel.searchCompleted && viewModel.searchResults.isEmpty {
                                EmptySearchResultView(searchText: searchText)
                                    .frame(height: 300)
                            } else {
                                searchResultsView
                            }
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
                
                if isInitialLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在加载排行榜...")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.9))
                }
            }
            .navigationTitle("书城")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showAllCategories) {
            AllCategoriesView(viewModel: viewModel)
        }
        .onAppear {
            if !hasInitialized {
                viewModel.loadInitialData()
                hasInitialized = true
                // 设置一个最短的加载时间，避免闪烁
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInitialLoading = false
                }
            }
        }
        .onDisappear {
            viewModel.pauseAllLoading()
        }
        .overlay(
            ZStack {
                if isLoading {
                    Color.black.opacity(0.5)  // 背景半透明
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text(loadingMessage)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("请候...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .frame(width: 200, height: 150)
                    .background(Color.gray)  // 对话框背景不透明
                    .cornerRadius(20)
                    .shadow(radius: 10)
                }
            }
            .animation(.easeInOut, value: isLoading)
        )
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults) { book in
                    NavigationLink(destination: BookInfoView(book: book)
                        .onAppear {
                            settingsViewModel.addBrowsingRecord(book)
                        }
                    ) {
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
                            .unredacted()
                        Spacer()
                        if viewModel.isCategoryLoaded(category) {
                            NavigationLink(destination: CategoryDetailView(category: category, viewModel: viewModel)) {
                                Text("看完整榜单 >")
                                    .font(.system(size: 14, design: .serif))
                                    .foregroundColor(.blue)
                                    .unredacted()
                            }
                        } else {
                            Text("完整榜单 >")
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(.gray)
                                .opacity(0.5)
                                .unredacted()
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(0..<5) { index in
                            if index < category.books.count {
                                RankedBookItemView(viewModel: viewModel, book: category.books[index], rank: index + 1, isLoading: $isLoading, loadingMessage: $loadingMessage)
                                    .unredacted()
                            } else {
                                PlaceholderRankedBookItemView(rank: index + 1)
                            }
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
    
    private var categoryRankingsPlaceholder: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(0..<4) { categoryIndex in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 22)
                        Spacer()
                        Text("看完整榜单 >")
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(.gray)
                            .opacity(0.5)
                    }
                    .padding(.horizontal)
                    
                    // 书籍列表占位符
                    VStack(spacing: 0) {
                        ForEach(0..<5) { bookIndex in
                            HStack(spacing: 15) {
                                Text("\(bookIndex + 1)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 80)
                                    .cornerRadius(5)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 16)
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 14)
                                        .frame(width: 100)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                            
                            if bookIndex < 4 {
                                Divider().padding(.leading, 45)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                if categoryIndex < 3 {
                    Divider()
                }
            }
        }
        .padding(.top)
        .redacted(reason: .placeholder)
        .shimmering()
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
    @FocusState private var isFocused: Bool
    @Binding var isSearching: Bool
    var onSubmit: () -> Void
    var onClear: () -> Void
    @State private var showEmptyAlert = false
    
    var body: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("输入书名或作者", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isFocused)
                    .onSubmit {
                        if !text.trim().isEmpty {
                            onSubmit()
                            isSearching = true
                        } else {
                            showEmptyAlert = true
                        }
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        if isSearching {
                            onClear()
                            isSearching = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if isFocused && !isSearching {
                // 输入状态显示搜索按钮
                Button(action: {
                    if !text.trim().isEmpty {
                        onSubmit()
                        isSearching = true
                        isFocused = false
                    } else {
                        showEmptyAlert = true
                    }
                }) {
                    Text("搜索")
                        .foregroundColor(.blue)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if isSearching {
                // 搜索完成后显示取消按钮
                Button(action: {
                    text = ""
                    isSearching = false
                    onClear()
                }) {
                    Text("取消")
                        .foregroundColor(.blue)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .animation(.easeInOut(duration: 0.2), value: text)
        .animation(.easeInOut(duration: 0.2), value: isSearching)
        .alert("提示", isPresented: $showEmptyAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("请输入书名或作者关键词")
        }
    }
}

extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
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
    @Binding var isLoading: Bool
    @Binding var loadingMessage: String
    @State private var isShowingBookInfo = false
    
    var body: some View {
        Button(action: {
            viewModel.pauseAllLoading()
            isShowingBookInfo = true
        }) {
            HStack(spacing: 15) {
                // 排名
                Text("\(rank)")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(rank <= 3 ? .orange : .gray)
                    .frame(width: 30, alignment: .center)
                    .unredacted()
                    .allowsHitTesting(false)
                
                // 封面图
                if let coverURL = viewModel.bookCache[book.link]?.coverURL,
                   !coverURL.isEmpty {
                    AsyncImage(url: URL(string: coverURL)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .shimmering()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .unredacted()
                        case .failure:
                            Image(systemName: "book.closed")
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 60, height: 80)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shimmering()
                }
                
                // 文字信息
                VStack(alignment: .leading, spacing: 8) {
                    if let title = viewModel.bookCache[book.link]?.title {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .unredacted()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 16)
                            .shimmering()
                    }
                    
                    if let author = viewModel.bookCache[book.link]?.author {
                        Text(author)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .unredacted()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 14)
                            .frame(width: 100)
                            .shimmering()
                    }
                    
                    if let introduction = viewModel.bookCache[book.link]?.introduction {
                        Text(introduction.components(separatedBy: " | ").first ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .unredacted()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 12)
                            .frame(width: 160)
                            .shimmering()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(UIColor.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .background(
            NavigationLink(
                destination: BookInfoView(book: Book(
                    title: viewModel.bookCache[book.link]?.title ?? book.name,
                    author: viewModel.bookCache[book.link]?.author ?? book.author,
                    coverURL: viewModel.bookCache[book.link]?.coverURL ?? "",
                    lastUpdated: "",
                    status: "",
                    introduction: viewModel.bookCache[book.link]?.introduction ?? "",
                    chapters: [],
                    link: book.link
                ))
                .onDisappear {
                    viewModel.resumeAllLoading()
                },
                isActive: $isShowingBookInfo
            ) {
                EmptyView()
            }
        )
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
                .onAppear {
                    viewModel.preloadTopBooksForCategory(category)
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
    @State private var loadedCount = 20
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var loadedItems = Set<String>()
    @State private var isInitialLoading = true
    
    var body: some View {
        Group {
            if isInitialLoading {
                VStack(spacing: 20) {
                    ForEach(0..<5) { index in
                        PlaceholderRankedBookItemView(rank: index + 1)
                            .padding(.horizontal)
                    }
                }
                .redacted(reason: .placeholder)
                .shimmering()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        if category.books.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("暂无数据")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(category.books.prefix(loadedCount).enumerated()), id: \.element.link) { index, book in
                                    RankedBookItemView(viewModel: viewModel,
                                                     book: book,
                                                     rank: index + 1,
                                                     isLoading: $isLoading,
                                                     loadingMessage: $loadingMessage)
                                    
                                    if index < category.books.prefix(loadedCount).count - 1 {
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.top)
                            
                            if loadedCount < category.books.count {
                                Button("加载更多") {
                                    loadMore()
                                }
                                .padding()
                            }
                        }
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .navigationTitle(category.name)
        .onAppear {
            viewModel.resumeLoading()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                preloadInitialBooks()
                isInitialLoading = false
            }
        }
        .onDisappear {
            // 只暂停加载，不清除缓存
            viewModel.pauseLoading()
        }
    }
    
    private func preloadInitialBooks() {
        guard !category.books.isEmpty else { return }
        
        let initialBooks = Array(category.books.prefix(loadedCount))
        for book in initialBooks {
            if viewModel.bookCache[book.link] != nil {
                loadedItems.insert(book.link)
            }
        }
        viewModel.preloadTopBooksForCategory(category)
    }
    
    private func loadMore() {
        guard !category.books.isEmpty else { return }
        
        let newCount = min(loadedCount + 20, category.books.count)
        viewModel.fetchTopBooksForCategory(category, count: newCount)
        loadedCount = newCount
    }
}

struct PlaceholderRankedBookItemView: View {
    let rank: Int
    
    var body: some View {
        HStack(spacing: 15) {
            Text("\(rank)")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(rank <= 3 ? .orange : .gray)
                .frame(width: 30, alignment: .center)
            
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 16)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 14)
                    .frame(width: 100)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                    .frame(width: 60)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.trailing, 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

struct BasicBookInfo {
    let title: String
    let author: String
    let introduction: String
    var coverURL: String
}

extension Color {
    static let charcoal = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let tan = Color(red: 0.82, green: 0.71, blue: 0.55)
    static let navy = Color(red: 0.0, green: 0.0, blue: 0.5)
    static let darkRed = Color(red: 0.5, green: 0.0, blue: 0.0)
}

struct EmptySearchResultView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("未找到相关书籍")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("\"\(searchText)\"")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("换个关键词试试吧")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

extension Book {
    static var placeholder: Book {
        Book(
            title: "",
            author: "",
            coverURL: "",
            lastUpdated: "",
            status: "",
            introduction: "",
            chapters: [],
            link: ""
        )
    }
}

struct ShimmeringModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Color.white
                        .opacity(0.3)
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, .white.opacity(0.7), .clear]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width/3)
                                .offset(x: -geometry.size.width/3 + geometry.size.width * phase)
                        )
                }
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmeringModifier())
    }
}

