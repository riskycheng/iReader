import SwiftUI

struct BookLibrariesView: View {
    @StateObject private var viewModel = BookLibrariesViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                bookList
                
                if viewModel.isLoading && viewModel.books.isEmpty {
                    ProgressView("Loading books...")
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .navigationTitle("书架")
        }
        .onAppear {
            viewModel.loadBooks()
        }
    }
    
    private var bookList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 20)], spacing: 20) {
                ForEach(viewModel.books) { book in
                    NavigationLink(destination: BookReadingView(book: book)) {
                        BookCoverView(book: book)
                    }
                }
                AddBookButton()
            }
            .padding()
        }
        .refreshable {
            viewModel.refreshBooks()
        }
        .overlay(
            Group {
                if viewModel.isLoading && !viewModel.books.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 10)
                            Spacer()
                        }
                    }
                }
            }
        )
    }
    
    private var refreshButton: some View {
        Button(action: {
            viewModel.refreshBooks()
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
    }
}


class BookLibrariesViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let bookURLs = [
        "https://www.bqgda.cc/books/9680/",
        "https://www.bqgda.cc/books/160252/",
        "https://www.bqgda.cc/books/16457/",
        "https://www.bqgda.cc/books/173469/"
    ]
    
    private let baseURL = "https://www.bqgda.cc/"
    private let cacheKey = "CachedBooks"
    private let cacheTimestampKey = "CachedBooksTimestamp"
    private let cacheDuration: TimeInterval = 24 * 60 * 60 // 24 hours in seconds
    
    private var refreshTask: Task<Void, Never>?
    
    func loadBooks(forceRefresh: Bool = false) {
        print("Starting to load books. Force refresh: \(forceRefresh)")
        isLoading = true
        errorMessage = nil
        
        if !forceRefresh, let cachedBooks = loadCachedBooks(), isCacheValid() {
            print("Loaded \(cachedBooks.count) valid books from cache")
            self.books = cachedBooks
            isLoading = false
            printBooksInfo(cachedBooks)
        } else {
            print("Cache is invalid or empty, or force refresh requested. Fetching books from network")
            refreshBooks()
        }
    }
    
    func refreshBooks() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            do {
                isLoading = true
                errorMessage = nil
                
                let refreshedBooks = try await fetchBooksFromNetworkAsync()
                updateBooksInPlace(with: refreshedBooks)
                cacheBooks(books)
                printBooksInfo(books)
            } catch {
                if error is CancellationError {
                    print("Refresh task was cancelled")
                } else {
                    errorMessage = "Error refreshing books: \(error.localizedDescription)"
                    print("Error refreshing books: \(error)")
                }
            }
            isLoading = false
        }
    }
    
    private func updateBooksInPlace(with newBooks: [Book]) {
        var updatedBooks = books
        
        for newBook in newBooks {
            if let index = updatedBooks.firstIndex(where: { $0.id == newBook.id }) {
                updatedBooks[index] = newBook
            } else {
                updatedBooks.append(newBook)
            }
        }
        
        // Remove books that are no longer in the new list
        updatedBooks.removeAll { book in
            !newBooks.contains { $0.id == book.id }
        }
        
        books = updatedBooks
    }
    
    private func fetchBooksFromNetworkAsync() async throws -> [Book] {
        try await withThrowingTaskGroup(of: Book?.self) { group -> [Book] in
            for bookURL in bookURLs {
                group.addTask {
                    print("Fetching book from URL: \(bookURL)")
                    guard let url = URL(string: bookURL) else {
                        print("Invalid URL: \(bookURL)")
                        throw URLError(.badURL)
                    }
                    let (data, _) = try await URLSession.shared.data(from: url)
                    print("Received data for URL: \(bookURL)")
                    guard let html = String(data: data, encoding: .utf8) else {
                        print("Failed to convert data to string for URL: \(bookURL)")
                        throw NSError(domain: "BookParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to convert data to string"])
                    }
                    if let book = HTMLBookParser.parseBasicBookInfo(html, baseURL: self.baseURL, bookURL: bookURL) {
                        print("Successfully parsed book: \(book.title) with link: \(book.link)")
                        return book
                    } else {
                        print("Failed to parse book from URL: \(bookURL)")
                        return nil
                    }
                }
            }
            
            var books: [Book] = []
            for try await book in group {
                if let book = book {
                    books.append(book)
                }
            }
            print("Fetched \(books.count) books from network")
            return books
        }
    }
    
    
    
    
    private func loadCachedBooks() -> [Book]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            print("No cached books found")
            return nil
        }
        
        do {
            let cachedBooks = try JSONDecoder().decode([Book].self, from: data)
            print("Successfully loaded \(cachedBooks.count) books from cache")
            return cachedBooks
        } catch {
            print("Error decoding cached books: \(error)")
            return nil
        }
    }
    
    private func cacheBooks(_ books: [Book]) {
        do {
            let data = try JSONEncoder().encode(books)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
            print("Successfully cached \(books.count) books")
        } catch {
            print("Error caching books: \(error)")
        }
    }
    
    private func isCacheValid() -> Bool {
        guard let cachedBooks = loadCachedBooks(), !cachedBooks.isEmpty else {
            return false
        }
        
        let cachedTimestamp = UserDefaults.standard.double(forKey: cacheTimestampKey)
        let currentTimestamp = Date().timeIntervalSince1970
        
        return (currentTimestamp - cachedTimestamp) < cacheDuration
    }
    
    private func printBooksInfo(_ books: [Book]) {
        for (index, book) in books.enumerated() {
            print("\nBook #\(index + 1) Info:")
            print("Title: \(book.title)")
            print("Author: \(book.author)")
            print("Cover URL: \(book.coverURL)")
            print("Last Updated: \(book.lastUpdated)")
            print("Status: \(book.status)")
            print("Introduction: \(book.introduction.prefix(100))...")
            print("Book Link: \(book.link)")
            print("Number of Chapters: \(book.chapters.count)")
            if let firstChapter = book.chapters.first {
                print("First Chapter Title: \(firstChapter.title)")
                print("First Chapter Link: \(firstChapter.link)")
            }
            if let lastChapter = book.chapters.last, book.chapters.count > 1 {
                print("Last Chapter Title: \(lastChapter.title)")
                print("Last Chapter Link: \(lastChapter.link)")
            }
            print("--------------------")
        }
    }
}



struct BookCoverView: View {
    let book: Book
    @StateObject private var imageLoader = ImageLoader()
    
    var body: some View {
        VStack {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 135)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 90, height: 135)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                    )
            }
            Text(book.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(width: 90)
            Text(book.author)
                .font(.system(size: 10, weight: .light))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 90)
        }
        .frame(width: 100, height: 180)
        .onAppear {
            imageLoader.loadImage(from: book.coverURL)
        }
    }
}




class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var url: URL?
    private var cache: ImageCache?
    
    init(cache: ImageCache? = nil) {
        self.cache = cache ?? ImageCache.shared
    }
    
    func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL for image: \(urlString)")
            return
        }
        self.url = url
        
        if let cachedImage = cache?[url] {
            print("Image loaded from cache: \(url)")
            self.image = cachedImage
            return
        }
        
        print("Fetching image from URL: \(url)")
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error loading image: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let loadedImage = UIImage(data: data) else {
                print("Invalid image data received from URL: \(url)")
                return
            }
            
            DispatchQueue.main.async {
                print("Image successfully loaded and cached: \(url)")
                self.cache?[url] = loadedImage
                if self.url == url {
                    self.image = loadedImage
                }
            }
        }.resume()
    }
}

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSURL, UIImage>()
    
    subscript(_ url: URL) -> UIImage? {
        get { cache.object(forKey: url as NSURL) }
        set {
            if let newValue = newValue {
                cache.setObject(newValue, forKey: url as NSURL)
            } else {
                cache.removeObject(forKey: url as NSURL)
            }
        }
    }
}

struct AddBookButton: View {
    var body: some View {
        VStack {
            Image(systemName: "plus")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)
            Text("添加书籍")
                .font(.caption)
        }
        .frame(width: 90, height: 170)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

struct BookLibrariesView_Previews: PreviewProvider {
    static var previews: some View {
        BookLibrariesView()
    }
}
