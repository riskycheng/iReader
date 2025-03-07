import Foundation
import Combine
import SwiftUI

class LibraryManager: ObservableObject {
    @Published var books: [Book] = []
    private let userDefaultsKey = "UserLibrary"
    private let removedBooksKey = "RemovedBooks"
    private var bookCovers: [UUID: Image] = [:]
    private let coverCacheKey = "BookCoverCache"
    
    static let shared = LibraryManager()
    
    private init() {
        loadBooks()
        loadCachedCovers()
    }
    
    func addBook(_ book: Book, withCoverImage coverImage: Image? = nil) {
        if !books.contains(where: { $0.link == book.link }) {
            books.append(book)
            if let coverImage = coverImage {
                bookCovers[book.id] = coverImage
                saveCachedCovers()
            }
            saveBooks()
            // 发送通知，包含封面图片
            NotificationCenter.default.post(
                name: NSNotification.Name("LibraryBookAdded"),
                object: nil,
                userInfo: [
                    "book": book,
                    "coverImage": coverImage as Any
                ]
            )
        }
    }
    
    func removeBook(_ book: Book) {
        books.removeAll { $0.link == book.link }
        addToRemovedBooks(book.id)
        saveBooks()
    }
    
    func isBookInLibrary(_ book: Book) -> Bool {
        return books.contains { $0.link == book.link }
    }
    
    func updateBooks(_ updatedBooks: [Book]) {
        self.books = updatedBooks
        saveBooks()
    }
    
    func refreshBooks() async throws {
        // In a real app, you might fetch updated book information from a server here
        // For now, we'll just use the existing books
        let fetchedBooks = self.books
        
        // Filter out removed books
        let filteredBooks = fetchedBooks.filter { !isBookRemoved($0.id) }
        
        // Update books on the main thread
        await MainActor.run {
            self.books = filteredBooks
            self.saveBooks()
        }
    }
    
    func getReadingProgress(for bookId: UUID) -> ReadingProgress? {
        // 实现获取阅读进度的逻辑
        // 例如，从 UserDefaults 或数据库中获取
        // 暂时返回 nil，您需要根据实际情况实现此方法
        return nil
    }
    
    private func loadBooks() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let decoder = JSONDecoder()
                books = try decoder.decode([Book].self, from: data)
                #if DEBUG
                print("LibraryManager 中的书籍数量: \(books.count)")
                #endif
            } catch {
                books = []
            }
        }
    }
    
    private func saveBooks() {
        if let encodedData = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encodedData, forKey: userDefaultsKey)
        }
    }
    
    private func addToRemovedBooks(_ bookId: UUID) {
        var removedBooks = UserDefaults.standard.object(forKey: removedBooksKey) as? [String] ?? []
        removedBooks.append(bookId.uuidString)
        UserDefaults.standard.set(removedBooks, forKey: removedBooksKey)
    }
    
    private func isBookRemoved(_ bookId: UUID) -> Bool {
        let removedBooks = UserDefaults.standard.object(forKey: removedBooksKey) as? [String] ?? []
        return removedBooks.contains(bookId.uuidString)
    }
    
    // 添加新方法用于保存下载状态
    func saveDownloadStatus(for bookId: UUID, isDownloaded: Bool) {
        let key = "book_downloaded_\(bookId.uuidString)"
        UserDefaults.standard.set(isDownloaded, forKey: key)
    }
    
    func isBookDownloaded(_ bookId: UUID) -> Bool {
        let key = "book_downloaded_\(bookId.uuidString)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func fetchBookChapters(for book: Book) async throws -> [Book.Chapter] {
        guard let url = URL(string: book.link) else {
            throw URLError(.badURL)
        }
        
        // 添加缓存策略
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8),
              let parsedBook = HTMLBookParser.parseHTML(html, baseURL: extractBaseURL(from: book.link), bookURL: book.link) else {
            throw URLError(.cannotParseResponse)
        }
        
        return parsedBook.chapters
    }
    
    func loadCachedChapters(for book: Book) async throws -> [Book.Chapter] {
        let fileURL = getLocalFileURL(for: book)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: fileURL)
        let localBook = try JSONDecoder().decode(Book.self, from: data)
        return localBook.chapters
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
    
    // 添加一个方法来保存更新状态
    func saveUpdateStatus(for bookId: UUID, hasUpdate: Bool) {
        let key = "book_has_update_\(bookId.uuidString)"
        UserDefaults.standard.set(hasUpdate, forKey: key)
    }
    
    // 添加一个方法来获取更新状态
    func hasUpdate(for bookId: UUID) -> Bool {
        let key = "book_has_update_\(bookId.uuidString)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func getCachedCoverImage(for bookId: UUID) -> Image? {
        if let image = bookCovers[bookId] {
            Task { @MainActor in
                if let uiImage = await ImageUtils.convertToUIImage(from: image) {
                    #if DEBUG
                    print("LibraryManager - 读取缓存封面大小: \(uiImage.size), 内存占用: \(ImageUtils.imageSizeInBytes(uiImage)) bytes")
                    #endif
                }
            }
            return image
        }
        return nil
    }
    
    // 添加封面缓存的保存和加载方法
    private func loadCachedCovers() {
        if let data = UserDefaults.standard.data(forKey: coverCacheKey),
           let uiImages = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: UIImage] {
            for (key, uiImage) in uiImages {
                if let bookId = UUID(uuidString: key) {
                    // 确保加载时也调整到统一尺寸
                    Task { @MainActor in
                        let resizedUIImage = await ImageUtils.resizeImage(uiImage, to: CGSize(width: 120, height: 160))
                        bookCovers[bookId] = Image(uiImage: resizedUIImage)
                    }
                }
            }
        }
    }
    
    private func saveCachedCovers() {
        var uiImages: [String: UIImage] = [:]
        
        Task { @MainActor in
            for (bookId, image) in bookCovers {
                if let uiImage = await ImageUtils.convertToUIImage(from: image) {
                    // 确保保存时是统一尺寸
                    let resizedUIImage = await ImageUtils.resizeImage(uiImage, to: CGSize(width: 120, height: 160))
                    uiImages[bookId.uuidString] = resizedUIImage
                }
            }
            
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: uiImages, requiringSecureCoding: false) {
                UserDefaults.standard.set(data, forKey: coverCacheKey)
            }
        }
    }
    
    func cacheBookCover(bookId: UUID, image: UIImage) {
        #if DEBUG
        print("原始图片大小: \(image.size)")
        #endif
        
        // 调整图片大小以减少内存占用
        let resizedUIImage = ImageUtils.resizeImage(image, to: CGSize(width: 120, height: 160))
        let swiftUIImage = Image(uiImage: resizedUIImage)
        
        #if DEBUG
        print("LibraryManager - 缓存封面调整为统一大小: \(resizedUIImage.size), 内存占用: \(ImageUtils.imageSizeInBytes(resizedUIImage)) bytes")
        #endif
        
        bookCovers[bookId] = swiftUIImage
        saveCachedCovers()
    }
    
    func getCoverImage(for bookId: UUID) -> Image? {
        return bookCovers[bookId]
    }
    
    func getAllBooks() -> [Book] {
        // 直接返回当前的 books 数组，因为它已经在 init() 时从 UserDefaults 加载了
        #if DEBUG
        print("LibraryManager 中的书籍数量: \(books.count)")
        #endif
        return books
    }
    
    func clearCoverCache() {
        bookCovers.removeAll()
        // Also remove from UserDefaults if you're caching there
        UserDefaults.standard.removeObject(forKey: coverCacheKey)
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

struct ReadingProgress {
    let chapterIndex: Int
    let pageIndex: Int
}

// 添加 Image 扩展，使用 ImageRenderer 而不是 UIHostingController
extension Image {
    @MainActor
    func asUIImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        return renderer.uiImage
    }
}
