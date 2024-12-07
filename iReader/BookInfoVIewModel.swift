import SwiftUI
import Combine
import SwiftSoup

class BookInfoViewModel: ObservableObject {
    @Published var book: Book
    @Published var isLoading = false
    @Published var isDownloading = false
    @Published var isDownloaded = false
    @Published var isAddedToLibrary: Bool = false
    @Published var currentChapterName = "" // Changed to a regular published property
    @Published var coverImage: Image? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private let libraryManager: LibraryManager
    private var dataTask: URLSessionDataTask?
    
    init(book: Book) {
        self.book = book
        self.libraryManager = LibraryManager.shared
        self.isAddedToLibrary = libraryManager.books.contains { $0.link == book.link }
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
        
        dataTask?.cancel()
        dataTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
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
        }
        dataTask?.resume()
    }
    
    private func parseChapters(from html: String) {
            do {
                let doc: Document = try SwiftSoup.parse(html)
                let chapterElements: Elements = try doc.select("div.listmain dd a")
                
                var chapters: [Book.Chapter] = []
                for element in chapterElements {
                    let title = try element.text()
                    let link = try element.attr("href")
                    
                    // Skip the "展开全部章节" chapter
                    if !title.contains("展开全部章节") {
                        chapters.append(Book.Chapter(title: title, link: link))
                        
                        DispatchQueue.main.async {
                            self.currentChapterName = title
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.book.chapters = chapters
                    self.objectWillChange.send() // Explicitly notify SwiftUI that the object has changed
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
        libraryManager.addBook(book, withCoverImage: coverImage)
        isAddedToLibrary = true
    }
    
    func removeFromLibrary() {
        libraryManager.removeBook(book)
        isAddedToLibrary = false
    }
    
    func cancelLoading() {
        dataTask?.cancel()
        isLoading = false
        currentChapterName = ""
    }
    
    func refreshLibraryStatus() {
        isAddedToLibrary = libraryManager.books.contains { $0.link == book.link }
    }
}
