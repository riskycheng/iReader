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
    
    func refreshBooks() async throws {
        // Simulating an API call to fetch books
        // In a real app, you would make an actual network request here
        let fetchedBooks: [Book] = [] // This would be the result of your API call
        
        // Filter out removed books
        let filteredBooks = fetchedBooks.filter { !isBookRemoved($0.id) }
        
        // Merge fetched books with existing books
        let mergedBooks = (books + filteredBooks).uniqued()
        
        // Update books on the main thread
        await MainActor.run {
            self.books = mergedBooks
            self.saveBooks()
        }
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
