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
            .navigationTitle("书架")
            .navigationBarItems(leading: EditButton(), trailing: Text("更多"))
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
    
    private let cacheKey = "CachedBooks"
    
    func loadBooks() {
        print("Starting to load books")
        isLoading = true
        errorMessage = nil
        
        if let cachedBooks = loadCachedBooks(), isCacheValid(cachedBooks) {
            print("Loaded \(cachedBooks.count) valid books from cache")
            self.books = cachedBooks
            isLoading = false
        } else {
            print("Cache is invalid or empty, fetching books from network")
            fetchBooksFromNetwork()
        }
    }
    
    func refreshBooks() async {
        print("Refreshing books")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let refreshedBooks = try await fetchBooksFromNetworkAsync()
            await MainActor.run {
                self.books = refreshedBooks
                self.cacheBooks(refreshedBooks)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error refreshing books: \(error.localizedDescription)"
                print("Error refreshing books: \(error)")
                isLoading = false
            }
        }
    }
    
    private func isCacheValid(_ cachedBooks: [Book]) -> Bool {
        return !cachedBooks.isEmpty && cachedBooks.allSatisfy { !$0.title.isEmpty && !$0.coverURL.isEmpty }
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
            for urlString in bookURLs {
                group.addTask {
                    print("Fetching book from URL: \(urlString)")
                    guard let url = URL(string: urlString) else {
                        print("Invalid URL: \(urlString)")
                        throw URLError(.badURL)
                    }
                    let (data, _) = try await URLSession.shared.data(from: url)
                    print("Received data for URL: \(urlString)")
                    guard let html = String(data: data, encoding: .utf8) else {
                        print("Failed to convert data to string for URL: \(urlString)")
                        throw NSError(domain: "BookParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to convert data to string"])
                    }
                    let book = HTMLBookParser.parseBasicBookInfo(html, baseURL: "https://www.bqgda.cc/")
                    if let book = book {
                        print("Successfully parsed book: \(book.title)")
                    } else {
                        print("Failed to parse book from URL: \(urlString)")
                    }
                    return book
                }
            }
            
            var books: [Book] = []
            for try await book in group {
                if let book = book {
                    books.append(book)
                }
            }
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
            print("Successfully cached \(books.count) books")
        } catch {
            print("Error caching books: \(error)")
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
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 120)
        }
        .frame(width: 150, height: 240)
        .onAppear {
            print("Loading image for book: \(book.title), URL: \(book.coverURL)")
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
