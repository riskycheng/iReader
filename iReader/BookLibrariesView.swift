import SwiftUI

struct BookLibrariesView: View {
    @StateObject private var viewModel = BookLibrariesViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading books...")
                } else if let error = viewModel.errorMessage {
                    Text(error)
                } else {
                    bookList
                }
            }
        }
        .onAppear {
            viewModel.loadBooks()
        }
    }
    
    private var bookList: some View {
        ScrollView {
            RefreshControl(coordinateSpace: .named("RefreshControl")) {
                await viewModel.refreshBooks()
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                ForEach(viewModel.books) { book in
                    NavigationLink(destination: BookReadingView(book: book)) {
                        BookCoverView(book: book)
                    }
                }
                AddBookButton()
            }
            .padding()
        }
        .coordinateSpace(name: "RefreshControl")
    }

    
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await viewModel.refreshBooks()
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
    }
}

struct RefreshControl: View {
    var coordinateSpace: CoordinateSpace
    var onRefresh: () async -> Void
    
    @State private var refresh: Task<Void, Never>? = nil
    
    var body: some View {
        GeometryReader { geo in
            if geo.frame(in: coordinateSpace).midY > 50 {
                Spacer()
                    .onAppear {
                        refresh = Task {
                            await onRefresh()
                        }
                    }
            } else if geo.frame(in: coordinateSpace).maxY < 1 {
                Spacer()
                    .onAppear {
                        refresh?.cancel()
                        refresh = nil
                    }
            }
            ZStack(alignment: .center) {
                if refresh != nil {
                    ProgressView()
                }
            }
            .frame(width: geo.size.width)
        }
        .padding(.top, -50)
    }
}

import SwiftUI

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
            fetchBooksFromNetwork()
        }
    }
    
    func refreshBooks() async {
        await MainActor.run {
            loadBooks(forceRefresh: true)
        }
    }
    
    private func fetchBooksFromNetwork() {
        Task {
            do {
                let loadedBooks = try await fetchBooksFromNetworkAsync()
                await MainActor.run {
                    self.books = loadedBooks
                    print("Loaded \(loadedBooks.count) books from network")
                    self.cacheBooks(loadedBooks)
                    isLoading = false
                    printBooksInfo(loadedBooks)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error loading books: \(error.localizedDescription)"
                    print("Error loading books: \(error)")
                    isLoading = false
                }
            }
        }
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
                    .frame(width: 120, height: 180)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 180)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                    )
            }
            Text(book.title)
                .font(.system(size: 16, weight: .medium))
                .lineLimit(1)
                .frame(width: 120)
            Text(book.author)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 120)
        }
        .frame(width: 150, height: 240)
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
        .frame(width: 150, height: 240)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

struct BookLibrariesView_Previews: PreviewProvider {
    static var previews: some View {
        BookLibrariesView()
    }
}
