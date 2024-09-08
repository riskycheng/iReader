import Foundation
import Combine

class LibraryManager: ObservableObject {
    @Published var books: [Book] = []
    private let userDefaultsKey = "UserLibrary"
    
    init() {
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
        saveBooks()
    }
    
    func isBookInLibrary(_ book: Book) -> Bool {
        return books.contains { $0.id == book.id }
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
}
