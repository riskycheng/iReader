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
                    ScrollView {
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
                }
            }
            .navigationTitle("书架")
            .navigationBarItems(leading: EditButton(), trailing: Text("更多"))
        }
        .onAppear {
            viewModel.loadBooks()
        }
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
        isLoading = true
        errorMessage = nil
        
        if let cachedBooks = loadCachedBooks() {
            self.books = cachedBooks
            isLoading = false
            return
        }
        
        Task {
            do {
                let loadedBooks = try await withThrowingTaskGroup(of: Book.self) { group -> [Book] in
                    for urlString in bookURLs {
                        group.addTask {
                            guard let url = URL(string: urlString) else {
                                throw URLError(.badURL)
                            }
                            return try await Book.parse(from: url, baseURL: "https://www.bqgda.cc/")
                        }
                    }
                    
                    var books: [Book] = []
                    for try await book in group {
                        books.append(book)
                    }
                    return books
                }
                
                await MainActor.run {
                    self.books = loadedBooks
                    self.cacheBooks(loadedBooks)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error loading books: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func loadCachedBooks() -> [Book]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }
        
        do {
            let cachedBooks = try JSONDecoder().decode([Book].self, from: data)
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
            print("Invalid URL: \(urlString)")
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
