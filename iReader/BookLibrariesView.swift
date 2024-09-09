import SwiftUI

struct BookLibrariesView: View {
    @StateObject private var viewModel = BookLibrariesViewModel()
       @EnvironmentObject private var libraryManager: LibraryManager
       @Binding var selectedBook: Book?
       @Binding var isShowingBookReader: Bool
       @State private var isShowingBookInfo = false
       @State private var bookForInfo: Book?
    
    var body: some View {
            NavigationView {
                ZStack {
                    ScrollView {
                        RefreshControl(coordinateSpace: .named("RefreshControl")) {
                            await viewModel.refreshBooks()
                        }
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 20)], spacing: 20) {
                            ForEach(viewModel.books) { book in
                                NavigationLink(destination: BookInfoView(book: book), tag: book, selection: $bookForInfo) {
                                    BookCoverView(book: book)
                                        .contextMenu {
                                            Button(action: {
                                                bookForInfo = book
                                            }) {
                                                Label("Book Info", systemImage: "info.circle")
                                            }
                                            
                                            Button(action: {
                                                libraryManager.removeBook(book)
                                                viewModel.loadBooks()
                                            }) {
                                                Label("Remove", systemImage: "trash")
                                            }
                                        }
                                        .onTapGesture {
                                            selectedBook = book
                                            isShowingBookReader = true
                                        }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            AddBookButton()
                        }
                        .padding()
                    }
                    .coordinateSpace(name: "RefreshControl")
                    
                    if viewModel.isLoading {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        
                        loadingView
                            .transition(.opacity)
                    }
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                }
                .navigationTitle("书架")
            }
            .onAppear {
                viewModel.setLibraryManager(libraryManager)
                if viewModel.books.isEmpty {
                    viewModel.loadBooks()
                }
            }
        }
    
    private var combinedBooks: [Book] {
           // Combine books from viewModel and libraryManager, removing duplicates
           let allBooks = viewModel.books + libraryManager.books
           return Array(Set(allBooks))
       }
    
    private var bookList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 20)], spacing: 20) {
                ForEach(viewModel.books) { book in
                    BookCoverView(book: book)
                        .onTapGesture {
                            selectedBook = book
                            isShowingBookReader = true
                        }
                }
                AddBookButton()
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshBooks()
        }
    }
    
    private var loadingView: some View {
          VStack(spacing: 20) {
              ProgressView()
                  .scaleEffect(1.5)
              Text(viewModel.loadingMessage)
                  .font(.headline)
              Text("\(viewModel.loadedBooksCount)/\(viewModel.totalBooksCount) books loaded")
                  .font(.subheadline)
              ProgressView(value: Double(viewModel.loadedBooksCount), total: Double(viewModel.totalBooksCount))
                  .frame(width: 200)
          }
          .padding()
          .background(Color(.systemBackground))
          .cornerRadius(15)
          .shadow(radius: 10)
      }
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await viewModel.refreshBooks()
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
    }
}

struct RefreshControl: View {
    var coordinateSpace: CoordinateSpace
    var onRefresh: () async -> Void
    @State private var isRefreshing = false
    @State private var progress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let threshold: CGFloat = 50
            let y = geo.frame(in: coordinateSpace).minY
            let pullProgress = min(max(0, y / threshold), 1)
            
            ZStack(alignment: .center) {
                if isRefreshing {
                    ProgressView()
                } else {
                    ProgressView(value: pullProgress)
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .frame(width: geo.size.width, height: threshold)
            .opacity(pullProgress)
            .onChange(of: y) { newValue in
                progress = pullProgress
                if newValue > threshold && !isRefreshing {
                    isRefreshing = true
                    Task {
                        await onRefresh()
                        isRefreshing = false
                    }
                }
            }
        }
        .padding(.top, -50)
    }
}


class BookLibrariesViewModel: ObservableObject {
    @Published var books: [Book] = []
       @Published var isLoading = false
       @Published var errorMessage: String?
       @Published var loadingMessage = "Loading books..."
       @Published var loadedBooksCount = 0
       @Published var totalBooksCount = 0
       
       private weak var libraryManager: LibraryManager?
       
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
       
       func setLibraryManager(_ manager: LibraryManager) {
           self.libraryManager = manager
       }
       
    func loadBooks(forceRefresh: Bool = false) {
            Task {
                await MainActor.run {
                    isLoading = true
                    errorMessage = nil
                    loadingMessage = "Checking cache..."
                }
                
                if !forceRefresh, let cachedBooks = loadCachedBooks(), isCacheValid() {
                    await MainActor.run {
                        self.books = self.mergeBooksWithLibrary(cachedBooks)
                        isLoading = false
                        loadingMessage = "Books loaded from cache"
                        loadedBooksCount = self.books.count
                        totalBooksCount = self.books.count
                    }
                } else {
                    await refreshBooks()
                }
            }
        }
        
    
    func refreshBooks() async {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
                loadingMessage = "Refreshing all books..."
                loadedBooksCount = 0
            }
            
            do {
                let libraryBooks = libraryManager?.books ?? []
                var allBookURLs = Set(bookURLs)
                libraryBooks.forEach { book in
                    if let url = URL(string: book.link) {
                        allBookURLs.insert(url.absoluteString)
                    }
                }
                
                let totalCount = allBookURLs.count
                await updateTotalCount(totalCount)
                
                var refreshedBooks: [Book] = []
                
                for (index, bookURL) in allBookURLs.enumerated() {
                    guard let url = URL(string: bookURL) else { continue }
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let html = String(data: data, encoding: .utf8),
                       let book = HTMLBookParser.parseBasicBookInfo(html, baseURL: baseURL, bookURL: bookURL) {
                        if !refreshedBooks.contains(where: { $0.title == book.title }) {
                            refreshedBooks.append(book)
                        }
                        await updateLoadingProgress(index + 1, bookTitle: book.title)
                    }
                }
                
                await finalizeRefresh(refreshedBooks)
            } catch {
                await handleRefreshError(error)
            }
        }
        
        @MainActor
        private func updateTotalCount(_ count: Int) {
            totalBooksCount = count
        }
        
        @MainActor
        private func updateLoadingProgress(_ count: Int, bookTitle: String) {
            loadedBooksCount = count
            loadingMessage = "Loaded \(bookTitle)"
        }
        
        @MainActor
        private func finalizeRefresh(_ refreshedBooks: [Book]) {
            self.books = refreshedBooks
            cacheBooks(self.books)
            loadingMessage = "All books updated"
            isLoading = false
            loadedBooksCount = self.books.count
            totalBooksCount = self.books.count
        }
        
        @MainActor
        private func handleRefreshError(_ error: Error) {
            errorMessage = "Error refreshing books: \(error.localizedDescription)"
            loadingMessage = "Error occurred"
            isLoading = false
        }
    
        private func mergeBooksWithLibrary(_ fetchedBooks: [Book]) -> [Book] {
            var mergedBooks = fetchedBooks
            if let libraryBooks = libraryManager?.books {
                for libraryBook in libraryBooks {
                    if !mergedBooks.contains(where: { $0.title == libraryBook.title }) {
                        mergedBooks.append(libraryBook)
                    }
                }
            }
            return mergedBooks
        }
    
   
    private func fetchBooksFromNetworkAsync() async throws -> [Book] {
            var fetchedBooks: [Book] = []
            for (index, bookURL) in bookURLs.enumerated() {
                guard let url = URL(string: bookURL) else { continue }
                let (data, _) = try await URLSession.shared.data(from: url)
                if let html = String(data: data, encoding: .utf8),
                   let book = HTMLBookParser.parseBasicBookInfo(html, baseURL: baseURL, bookURL: bookURL) {
                    fetchedBooks.append(book)
                    await MainActor.run {
                        loadedBooksCount = index + 1
                        loadingMessage = "Loaded \(book.title)"
                    }
                }
            }
            return fetchedBooks
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
        loadedBooksCount = updatedBooks.count
        totalBooksCount = updatedBooks.count
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
        BookLibrariesView(
            selectedBook: .constant(nil),
            isShowingBookReader: .constant(false)
        )
    }
}
