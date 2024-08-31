import SwiftUI

struct BookReadingView: View {
    @StateObject private var bookLoader = BookLoader()
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @State private var pages: [String] = []
    @State private var chapterIndex: Int = 0
    
    let fontSize: CGFloat = 20
    let lineSpacing: CGFloat = 8
    
    let baseURL: String
    let bookURL: String
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let book = bookLoader.book {
                    bookContent(for: book, in: geometry)
                } else if bookLoader.isLoading {
                    ProgressView("Loading book...")
                } else if let error = bookLoader.error {
                    Text("Error: \(error.localizedDescription)")
                } else {
                    Text("No book data available")
                }
            }
        }
        .onAppear {
            bookLoader.loadBook(baseURL: baseURL, bookURL: bookURL)
        }
    }
    
    private func bookContent(for book: Book, in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top Bar with Book Name and Chapter Name
            HStack {
                Text(book.title)
                    .font(.headline)
                Spacer()
                Text(book.chapters[chapterIndex].title)
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 5)
            
            // Content Display
            if let chapterContent = bookLoader.chapterContent {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(pages[index])
                                .font(.custom("Georgia", size: fontSize))
                                .lineSpacing(lineSpacing)
                                .frame(width: geometry.size.width - 40, alignment: .topLeading)
                                .padding(.horizontal, 20)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height - 100)
                        .tag(index + 1)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            } else {
                ProgressView("Loading chapter...")
            }
            
            // Bottom Bar with Navigation and Page Indexer
            HStack {
                Button(action: previousChapter) {
                    Image(systemName: "chevron.left")
                }
                .disabled(chapterIndex == 0)
                
                Spacer()
                
                Text("\(currentPage) / \(totalPages)")
                    .font(.footnote)
                
                Spacer()
                
                Button(action: nextChapter) {
                    Image(systemName: "chevron.right")
                }
                .disabled(chapterIndex == book.chapters.count - 1)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadChapterContent(for: book)
        }
        .onChange(of: bookLoader.chapterContent) { _ in
            splitContentIntoPages()
        }
    }
    
    private func loadChapterContent(for book: Book) {
        guard chapterIndex < book.chapters.count else { return }
        let chapterURL = book.chapters[chapterIndex].link
        bookLoader.loadChapterContent(chapterURL: chapterURL, baseURL: baseURL)
    }
    
    private func splitContentIntoPages() {
        guard let content = bookLoader.chapterContent else { return }
        let screenSize = UIScreen.main.bounds.size
        let contentSize = CGSize(width: screenSize.width - 40, height: screenSize.height - 100)
        let font = UIFont(name: "Georgia", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        
        pages = BookUtils.splitContentIntoPages(content: content, size: contentSize, font: font, lineSpacing: lineSpacing)
        totalPages = pages.count
        currentPage = 1
    }
    
    private func previousChapter() {
        guard chapterIndex > 0 else { return }
        chapterIndex -= 1
        loadChapterContent(for: bookLoader.book!)
    }
    
    private func nextChapter() {
        guard let book = bookLoader.book, chapterIndex < book.chapters.count - 1 else { return }
        chapterIndex += 1
        loadChapterContent(for: book)
    }
}

struct BookReadingView_Previews: PreviewProvider {
    static var previews: some View {
        BookReadingView(baseURL: "https://www.bqgda.cc/", bookURL: "https://www.bqgda.cc/books/9680/")
    }
}
