import Foundation
import Combine

class LibraryManager: ObservableObject {
    @Published var books: [Book] = []
    private let userDefaultsKey = "UserLibrary"
    private let removedBooksKey = "RemovedBooks"
    
    static let shared = LibraryManager()
    
    private init() {
        loadBooks()
    }
    
    func addBook(_ book: Book) {
        if !books.contains(where: { $0.id == book.id }) {
            books.append(book)
            saveBooks()
        }
    }
    
    func removeBook(_ book: Book) {
        books.removeAll { $0.id == book.id }
        addToRemovedBooks(book.id)
        saveBooks()
    }
    
    func isBookInLibrary(_ book: Book) -> Bool {
        return books.contains { $0.id == book.id }
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
            if let decodedBooks = try? JSONDecoder().decode([Book].self, from: data) {
                books = decodedBooks
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
