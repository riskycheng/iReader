import SwiftUI
import Combine
import SwiftSoup

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
        guard let url = URL(string: book.link) else {
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
                return
            }
            
            if let htmlString = String(data: data, encoding: .utf8) {
                self.parseChapters(from: htmlString)
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }.resume()
    }
    
    private func parseChapters(from html: String) {
        do {
            let doc: Document = try SwiftSoup.parse(html)
            let chapterElements: Elements = try doc.select("div.listmain dd a")
            
            var chapters: [Book.Chapter] = []
            for element in chapterElements {
                let title = try element.text()
                let link = try element.attr("href")
                chapters.append(Book.Chapter(title: title, link: link))
            }
            
            DispatchQueue.main.async {
                self.book.chapters = chapters
            }
        } catch {
            print("Error parsing chapters: \(error)")
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
