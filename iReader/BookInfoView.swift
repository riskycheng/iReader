import SwiftUI

struct BookInfoView: View {
    let book: Book
    @State private var isShowingBookReader = false
    @State private var isDownloading = false
    @State private var isAddedToLibrary = false
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var showChapterList = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Book cover
                AsyncImage(url: URL(string: book.coverURL)) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 120, height: 180)
                .cornerRadius(8)
                
                // Book title and author
                VStack(spacing: 5) {
                    Text(book.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Book details
                VStack(alignment: .leading, spacing: 10) {
                    Text("最后更新: \(book.lastUpdated)")
                    Text("状态: \(book.status)")
                    Text("简介: \(book.introduction)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Chapter info
                HStack {
                    Text("目录")
                        .font(.headline)
                    Spacer()
                    Button("查看目录") {
                        showChapterList = true
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 15) {
                    Button(action: {
                        isShowingBookReader = true
                    }) {
                        Text("开始阅读")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        downloadBook()
                    }) {
                        Text(isDownloading ? "下载中..." : "下载")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .disabled(isDownloading)
                    
                    Button(action: {
                        addToLibrary()
                    }) {
                        Text(isAddedToLibrary ? "已在书架" : "加入书架")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .disabled(isAddedToLibrary)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("书城")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingBookReader) {
            BookReadingView(book: book, isPresented: $isShowingBookReader)
        }
        .sheet(isPresented: $showChapterList) {
            ChapterListView(book: book)
        }
        .onAppear {
            isAddedToLibrary = libraryManager.isBookInLibrary(book)
        }
    }
    
    private func downloadBook() {
        isDownloading = true
        // Implement book downloading logic here
        DispatchQueue.global().async {
            // Simulating download process
            Thread.sleep(forTimeInterval: 2)
            DispatchQueue.main.async {
                isDownloading = false
                // Save book data to local storage
                saveBookToLocalStorage()
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
    
    private func addToLibrary() {
        libraryManager.addBook(book)
        isAddedToLibrary = true
    }
}

struct ChapterListView: View {
    let book: Book
    
    var body: some View {
        List {
            ForEach(book.chapters, id: \.title) { chapter in
                Text(chapter.title)
            }
        }
        .navigationTitle("章节列表")
    }
}
