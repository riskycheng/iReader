import SwiftUI
import Combine

class BookInfoViewModel: ObservableObject {
    @Published var book: Book
    @Published var isLoading = false
    @Published var isDownloading = false
    @Published var isAddedToLibrary = false
    
    private var cancellables = Set<AnyCancellable>()
    private let libraryManager: LibraryManager
    
    init(book: Book, libraryManager: LibraryManager = .shared) {
        self.book = book
        self.libraryManager = libraryManager
        checkIfBookInLibrary()
    }
    
    func checkIfBookInLibrary() {
        isAddedToLibrary = libraryManager.isBookInLibrary(book)
    }
    
    func fetchBookDetails() {
        isLoading = true
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            // In a real app, you would parse the book details here
            self.book.chapters = [
                Book.Chapter(title: "第一章", link: ""),
                Book.Chapter(title: "第二章", link: ""),
                Book.Chapter(title: "第三章", link: "")
            ]
            self.isLoading = false
        }
    }
    
    func downloadBook() {
        isDownloading = true
        // Implement book downloading logic here
        DispatchQueue.global().async { [weak self] in
            // Simulating download process
            Thread.sleep(forTimeInterval: 2)
            DispatchQueue.main.async {
                self?.isDownloading = false
                self?.saveBookToLocalStorage()
            }
        }
    }
    
    private func saveBookToLocalStorage() {
        // Implement saving book data to local storage
        // This is a placeholder implementation
        let encoder = JSONEncoder()
        if let encodedBook = try? encoder.encode(book) {
            UserDefaults.standard.set(encodedBook, forKey: "downloaded_book_\(book.id)")
        }
    }
    
    func addToLibrary() {
        libraryManager.addBook(book)
        isAddedToLibrary = true
    }
}
