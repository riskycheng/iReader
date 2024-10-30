import Foundation
import Combine

// 如果 Chapter 是在其他文件中定义的，请确保导入正确的模块
// import YourModuleName

class BookLibrariesViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var loadingMessage = "Parsing books..."
    @Published var loadedBooksCount = 0
    @Published var totalBooksCount = 0
    @Published var currentBookName = "" // New property for current book name
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadingBookName: String = ""
    @Published var chapterContents: [String: String] = [:] // 用于存储章节内容的字典
    @Published var showDownloadStartedAlert = false
    @Published var downloadStartedBookName = ""
    @Published var isBookAlreadyDownloaded: Bool = false
    @Published var isRefreshCompleted = false
    @Published var lastUpdateTime: Date?
    
    var lastUpdateTimeString: String {
        guard let lastUpdate = lastUpdateTime else {
            return "尚未更新"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .full
        return "最后更新：" + formatter.localizedString(for: lastUpdate, relativeTo: Date())
    }
    
    private var libraryManager: LibraryManager?
    private var cancellables = Set<AnyCancellable>()
    
    private let minimumRefreshTime: TimeInterval = 2.0
    
    func setLibraryManager(_ manager: LibraryManager) {
        self.libraryManager = manager
        setupObservers()
        loadBooks()
    }
    
    private func setupObservers() {
        guard let libraryManager = libraryManager else { return }
        
        libraryManager.$books
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedBooks in
                self?.books = updatedBooks
                self?.totalBooksCount = updatedBooks.count
            }
            .store(in: &cancellables)
    }
    
    func loadBooks() {
        self.books = libraryManager?.books ?? []
        self.loadedBooksCount = books.count
        self.totalBooksCount = books.count
        print("Loaded \(books.count) books")
    }
    
    func refreshBooksOnRelease() async {
        print("Starting refreshBooksOnRelease")
        
        await MainActor.run {
            isLoading = true
            isRefreshCompleted = false
            errorMessage = nil
            loadingMessage = "正在更新书架..."
            loadedBooksCount = 0
            totalBooksCount = books.count
        }
        
        do {
            try await parseBooks()
            
            // 显示完成状态
            await MainActor.run {
                self.isRefreshCompleted = true
                self.lastUpdateTime = Date()
            }
            
            // 延迟1秒后关闭加载视图
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                isLoading = false
                loadingMessage = "更新完成"
                isRefreshCompleted = false
            }
        } catch {
            await handleRefreshError(error)
        }
    }
    
    private func parseBooks() async throws {
        guard let libraryManager = libraryManager else { return }
        
        var updatedBooks: [Book] = []
        
        for (index, book) in libraryManager.books.enumerated() {
            let startTime = Date()
            
            do {
                await MainActor.run {
                    self.currentBookName = book.title
                }
                
                let updatedBook = try await parseBookDetails(book)
                updatedBooks.append(updatedBook)
                
                // 确保每本书至少显示指定的最小时间
                let elapsedTime = Date().timeIntervalSince(startTime)
                if elapsedTime < minimumRefreshTime {
                    try await Task.sleep(nanoseconds: UInt64((minimumRefreshTime - elapsedTime) * 1_000_000_000))
                }
                
                await MainActor.run {
                    loadedBooksCount = index + 1
                    loadingMessage = "正在更新书架..."
                }
            } catch {
                print("Error parsing book: \(book.title), Error: \(error.localizedDescription)")
                updatedBooks.append(book)
            }
        }
        
        await updateBooksOnMainActor(updatedBooks)
    }
    
    @MainActor
    private func updateBooksOnMainActor(_ updatedBooks: [Book]) {
        self.books = updatedBooks
        libraryManager?.updateBooks(updatedBooks)
    }
    
    private func parseBookDetails(_ book: Book) async throws -> Book {
        if isBookDownloaded(book) {
            // 从本地加
            print("本地存在书籍：\(book.title)，从本地加载")
            return try loadBookFromLocal(book)
        } else {
            // 从网络加载
            print("本地不存在书籍：\(book.title)，从网络加载")
            return try await downloadBookDetails(book)
        }
    }
    
    private func downloadBookDetails(_ book: Book) async throws -> Book {
        // 检查本地是否已有下载的书籍
        if isBookDownloaded(book) {
            print("书籍已存在本地：\(book.title)")
            return try loadBookFromLocal(book)
        }
        
        guard let url = URL(string: book.link) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let html = String(data: data, encoding: .utf8) ?? ""
        
        guard let updatedBook = HTMLBookParser.parseHTML(html, baseURL: extractBaseURL(from: book.link), bookURL: book.link) else {
            throw URLError(.cannotParseResponse)
        }
        
        // 模拟下载进度
        for i in 1...100 {
            try await Task.sleep(nanoseconds: 10_000_000) // 模拟网络延迟
            await MainActor.run {
                self.downloadProgress = Double(i) / 100.0
            }
        }
        
        // 将书籍保存到本地
        try saveBookToLocal(updatedBook)
        print("书籍已下载并保存到本地：\(updatedBook.title)")
        
        return updatedBook
    }

    private func saveBookToLocal(_ book: Book) throws {
        let fileURL = getLocalFileURL(for: book)
        let data = try JSONEncoder().encode(book)
        try data.write(to: fileURL)
        print("书籍保存路径：\(fileURL.path)")
    }
    
    // 将 isBookDownloaded 方法改为 public
    func isBookDownloaded(_ book: Book) -> Bool {
        let fileURL = getLocalFileURL(for: book)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    private func loadBookFromLocal(_ book: Book) throws -> Book {
        let fileURL = getLocalFileURL(for: book)
        let data = try Data(contentsOf: fileURL)
        let localBook = try JSONDecoder().decode(Book.self, from: data)
        print("从本地加载了书籍：\(localBook.title)")
        return localBook
    }
    
    private func getLocalFileURL(for book: Book) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("\(book.id.uuidString).book")
    }
    
    private func extractBaseURL(from url: String) -> String {
        guard let url = URL(string: url) else { return "" }
        let components = url.pathComponents
        if components.count >= 3 {
            return url.absoluteString.replacingOccurrences(of: url.lastPathComponent, with: "")
        }
        return url.absoluteString
    }
    
    @MainActor
    private func handleRefreshError(_ error: Error) {
        errorMessage = "Error parsing books: \(error.localizedDescription)"
        loadingMessage = "Error occurred"
        isLoading = false
        print("Error occurred during parsing: \(error.localizedDescription)")
    }
    
    func removeBook(_ book: Book) {
        libraryManager?.removeBook(book)
        loadBooks()
        print("Removed book: \(book.title)")
    }
    
    @MainActor
    func downloadBook(_ book: Book) {
        guard !isDownloading else { return }
        
        if isBookDownloaded(book) {
            // 书籍已下载，显示提示
            isBookAlreadyDownloaded = true
            downloadStartedBookName = book.title
            showDownloadStartedAlert = true
            
            // 3秒后自动隐藏提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showDownloadStartedAlert = false
                self.isBookAlreadyDownloaded = false
            }
            return
        }

        // 书籍未下载，开始下载流程
        isDownloading = true
        isBookAlreadyDownloaded = false
        downloadingBookName = book.title
        downloadProgress = 0.0
        
        // 显示下载开始的提示
        downloadStartedBookName = book.title
        showDownloadStartedAlert = true
        
        // 3秒后自动隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showDownloadStartedAlert = false
        }
        
        // 打印要下载的书籍URL
        print("尝试下载书籍: \(book.title)")
        print("下载URL: \(book.link)")
        
        // 提取基础URL
        let baseURL = extractBaseURL(from: book.link)
        
        Task {
            do {
                let chapters = book.chapters
                let chunkSize = 10
                let totalChapters = chapters.count
                var completedChapters = 0
                
                for i in stride(from: 0, to: chapters.count, by: chunkSize) {
                    let end = min(i + chunkSize, chapters.count)
                    let chapterGroup = Array(chapters[i..<end])
                    
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for chapter in chapterGroup {
                            group.addTask {
                                // 构建完整的章节URL
                                let fullChapterURL = constructFullChapterURL(baseURL: baseURL, chapterLink: chapter.link)
                                
                                // 打印每个章节的URL
                                print("下载章节: \(chapter.title)")
                                print("章节URL: \(fullChapterURL)")
                                
                                try await self.downloadChapter(chapter, book: book, fullURL: fullChapterURL)
                                await MainActor.run {
                                    completedChapters += 1
                                    self.downloadProgress = Double(completedChapters) / Double(totalChapters)
                                }
                            }
                        }
                        // 等待所有任务完成
                        for try await _ in group {}
                    }
                }
                
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadProgress = 1.0
                    self.updateBookDownloadStatus(book)
                    libraryManager?.saveDownloadStatus(for: book.id, isDownloaded: true)
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "下载失败: \(error.localizedDescription)"
                    self.isDownloading = false
                }
                // 打印详细的错误信息
                print("下载失败: \(error)")
            }
        }
    }
    
    private func downloadChapter(_ chapter: Book.Chapter, book: Book, fullURL: String) async throws {
        // 使用章节的 title 或其他唯一标识来创建文件名
        let safeTitle = chapter.title.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        let chapterFileName = "\(book.id.uuidString)_\(safeTitle).chapter"
        
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chapterPath = documentsPath.appendingPathComponent(chapterFileName)
        
        if !fileManager.fileExists(atPath: chapterPath.path) {
            print("开始下载章节: \(chapter.title)")
            print("章节URL: \(fullURL)")
            let content = try await fetchChapterContent(fullURL)
            try content.write(to: chapterPath, atomically: true, encoding: .utf8)
            print("章节下载完成: \(chapter.title)")
        } else {
            print("章节已存在,跳过下载: \(chapter.title)")
        }
    }
    
    private func fetchChapterContent(_ url: String) async throws -> String {
        guard let url = URL(string: url) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return content
    }
    
    // 添加新方法来更新书籍的下载状态
    private func updateBookDownloadStatus(_ book: Book) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            var updatedBook = books[index]
            updatedBook.isDownloaded = true
            books[index] = updatedBook
            libraryManager?.updateBooks(books)
        }
    }
}

private func constructFullChapterURL(baseURL: String, chapterLink: String) -> String {
    if chapterLink.hasPrefix("http") {
        return chapterLink
    } else {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        let trimmedChapterLink = chapterLink.trimmingCharacters(in: .init(charactersIn: "/"))
        
        // 移除可能重复的 "books/" 部分
        let finalChapterLink = trimmedChapterLink.replacingOccurrences(of: "books/", with: "")
        
        return "\(trimmedBaseURL)/\(finalChapterLink)"
    }
}
