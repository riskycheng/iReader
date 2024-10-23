import Foundation
import Combine

// 如果 Chapter 是在其他文件中定义的，请确保导入正确的模块
// import YourModuleName

// 如果 Chapter 没有在其他地方定义，我们可以在这里定义它
struct Chapter: Codable, Identifiable {
    let id: UUID
    let title: String
    let link: String
    var content: String?
}

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
    
    private var libraryManager: LibraryManager?
    private var cancellables = Set<AnyCancellable>()
    
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
            errorMessage = nil
            loadingMessage = "Parsing books..."
            loadedBooksCount = 0
            totalBooksCount = books.count
        }
        print("Set isLoading to true")
        
        do {
            try await parseBooks()
        } catch {
            await handleRefreshError(error)
        }
        
        await MainActor.run {
            isLoading = false
            loadingMessage = "All books parsed"
            print("Set isLoading to false")
        }
    }
    
    
    
    private func parseBooks() async throws {
        guard let libraryManager = libraryManager else { return }
        
        var updatedBooks: [Book] = []
        
        for (index, book) in libraryManager.books.enumerated() {
            do {
                await MainActor.run {
                    self.currentBookName = book.title // Update current book name
                }
                let updatedBook = try await parseBookDetails(book)
                updatedBooks.append(updatedBook)
                
                await MainActor.run {
                    loadedBooksCount = index + 1
                    loadingMessage = "Parsed book \(loadedBooksCount) of \(totalBooksCount)"
                    print("\(loadedBooksCount)/\(totalBooksCount) books parsed")
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
            // 从本地加载
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
    
    private func isBookDownloaded(_ book: Book) -> Bool {
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
        return "\(url.scheme ?? "https")://\(url.host ?? "")"
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
    
    func downloadBook(_ book: Book) {
        isDownloading = true
        downloadProgress = 0.0
        downloadingBookName = book.title
        errorMessage = nil
        chapterContents.removeAll() // 清空之前的章节内容

        Task {
            do {
                print("开始下载书籍：\(book.title)")
                let downloadedBook = try await downloadBookDetails(book)
                
                // 下载所有章节内容
                let totalChapters = downloadedBook.chapters.count
                var updatedChapters: [Book.Chapter] = []
                
                for (index, chapter) in downloadedBook.chapters.enumerated() {
                    let (updatedChapter, content) = try await downloadChapterContent(chapter)
                    updatedChapters.append(updatedChapter)
                    chapterContents[chapter.link] = content // 使用章节链接作为键来存储内容
                    
                    await MainActor.run {
                        self.downloadProgress = Double(index + 1) / Double(totalChapters)
                        print("下载进度：\(Int(self.downloadProgress * 100))%")
                    }
                }
                
                let fullyDownloadedBook = Book(
                    id: downloadedBook.id,
                    title: downloadedBook.title,
                    author: downloadedBook.author,
                    coverURL: downloadedBook.coverURL,
                    lastUpdated: downloadedBook.lastUpdated,
                    status: downloadedBook.status,
                    introduction: downloadedBook.introduction,
                    chapters: updatedChapters,
                    link: downloadedBook.link,
                    bookmarks: downloadedBook.bookmarks
                )
                
                // 保存完整的书籍到本地
                try saveBookToLocal(fullyDownloadedBook)
                try saveChapterContentsToLocal(bookId: fullyDownloadedBook.id)
                
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadProgress = 1.0
                    self.books = self.books.map { $0.id == book.id ? fullyDownloadedBook : $0 }
                    self.libraryManager?.updateBooks(self.books)
                    print("成功下载并更新了书籍：\(book.title)")
                }
            } catch {
                await MainActor.run {
                    self.isDownloading = false
                    self.errorMessage = "下载失败：\(error.localizedDescription)"
                    print("下载书籍时出错：\(error.localizedDescription)")
                }
            }
        }
    }
    
    private func downloadChapterContent(_ chapter: Book.Chapter) async throws -> (Book.Chapter, String) {
        guard let url = URL(string: chapter.link) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let content = String(data: data, encoding: .utf8) ?? ""
        
        return (chapter, content)
    }
    
    private func saveChapterContentsToLocal(bookId: UUID) throws {
        let fileURL = getChapterContentsFileURL(for: bookId)
        let data = try JSONEncoder().encode(chapterContents)
        try data.write(to: fileURL)
        print("章节内容保存路径：\(fileURL.path)")
    }
    
    private func getChapterContentsFileURL(for bookId: UUID) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("\(bookId.uuidString)_chapters.json")
    }
    
    func loadChapterContentsFromLocal(bookId: UUID) throws {
        let fileURL = getChapterContentsFileURL(for: bookId)
        let data = try Data(contentsOf: fileURL)
        chapterContents = try JSONDecoder().decode([String: String].self, from: data)
        print("从本地加载了章节内容：\(fileURL.path)")
    }
}
