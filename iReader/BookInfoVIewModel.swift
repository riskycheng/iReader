import SwiftUI
import Combine

class BookInfoViewModel: ObservableObject {
    @Published var book: Book
    @Published var isLoading = false
    @Published var isDownloading = false
    @Published var isDownloaded = false
    @Published var isAddedToLibrary = false
    
    private var cancellables = Set<AnyCancellable>()
    private let libraryManager: LibraryManager
    
    init(book: Book, libraryManager: LibraryManager = .shared) {
        self.book = book
        self.libraryManager = libraryManager
        checkIfBookInLibrary()
        checkIfBookIsDownloaded()
    }
    
    func checkIfBookInLibrary() {
        isAddedToLibrary = libraryManager.isBookInLibrary(book)
    }
    
    func checkIfBookIsDownloaded() {
        isDownloaded = UserDefaults.standard.data(forKey: "downloaded_book_\(book.id)") != nil
    }
    
    func fetchBookDetails() {
        isLoading = true
        // In a real app, you would fetch the book details from a network call
        // For this example, we'll simulate a network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            // Here you would parse the real chapter data
            // For now, we'll just create some sample chapters
            self.book.chapters = (1...20).map { Book.Chapter(title: "第\($0)章", link: "") }
            self.isLoading = false
        }
    }
    
    func downloadBook() {
        guard !isDownloaded else { return }
        
        isDownloading = true
        // Implement book downloading logic here
        DispatchQueue.global().async { [weak self] in
            // Simulating download process
            Thread.sleep(forTimeInterval: 2)
            DispatchQueue.main.async {
                self?.isDownloading = false
                self?.isDownloaded = true
                self?.saveBookToLocalStorage()
            }
        }
    }
    
    private func saveBookToLocalStorage() {
        let encoder = JSONEncoder()
        if let encodedBook = try? encoder.encode(book) {
            UserDefaults.standard.set(encodedBook, forKey: "downloaded_book_\(book.id)")
        }
    }
    
    func addToLibrary() {
        libraryManager.addBook(book)
        isAddedToLibrary = true
    }
    
    func removeFromLibrary() {
        libraryManager.removeBook(book)
        isAddedToLibrary = false
    }
}
