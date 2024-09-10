import Foundation
import Combine

class BookLibrariesViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var loadingMessage = "Parsing books..."
    @Published var loadedBooksCount = 0
    @Published var totalBooksCount = 0
    @Published var currentBookName = "" // New property for current book name
    
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
        guard let url = URL(string: book.link) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let html = String(data: data, encoding: .utf8) ?? ""
        
        guard let updatedBook = HTMLBookParser.parseHTML(html, baseURL: extractBaseURL(from: book.link), bookURL: book.link) else {
            throw URLError(.cannotParseResponse)
        }
        
        return updatedBook
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
}
