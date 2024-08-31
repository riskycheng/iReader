import SwiftUI

struct BookReadingView: View {
    @StateObject private var bookLoader = BookLoader()
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 1
    @State private var pages: [String] = []
    @State private var chapterIndex: Int = 0
    @State private var showSettings: Bool = false
    @State private var showChapterList: Bool = false
    @State private var showFontSettings: Bool = false
    @State private var isDarkMode: Bool = false
    @State private var fontSize: CGFloat = 20
    @State private var fontFamily: String = "Georgia"
    @State private var dragOffset: CGFloat = 0
    
    let lineSpacing: CGFloat = 8
    let baseURL: String
    let bookURL: String
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let book = bookLoader.book {
                    bookContent(for: book, in: geometry)
                } else if bookLoader.isLoading {
                    ProgressView("Loading book...")
                } else if let error = bookLoader.error {
                    Text("Error: \(error.localizedDescription)")
                } else {
                    Text("No book data available")
                }
                
                if showSettings {
                    settingsPanel
                }
                
                if showChapterList {
                    chapterListView
                }
                
                if showFontSettings {
                    fontSettingsView
                }
            }
        }
        .onAppear {
            bookLoader.loadBook(baseURL: baseURL, bookURL: bookURL)
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
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
            if !pages.isEmpty {
                pageContent(in: geometry)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                let threshold = geometry.size.width * 0.2
                                if value.translation.width > threshold {
                                    previousPage()
                                } else if value.translation.width < -threshold {
                                    nextPage()
                                }
                                dragOffset = 0
                            }
                    )
            } else {
                ProgressView("Loading chapter...")
            }
            
            // Bottom Toolbar
            HStack {
                // Battery Status
                HStack {
                    Image(systemName: "battery.100")
                    Text("100%")
                }
                Spacer()
                // Page Indexer
                Text("\(currentPage + 1) / \(totalPages)")
            }
            .font(.footnote)
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
    
    private func pageContent(in geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach([-1, 0, 1], id: \.self) { offset in
                let pageIndex = currentPage + offset
                if pageIndex >= 0 && pageIndex < pages.count {
                    Text(pages[pageIndex])
                        .font(.custom(fontFamily, size: fontSize))
                        .lineSpacing(lineSpacing)
                        .frame(width: geometry.size.width - 40, height: geometry.size.height - 100, alignment: .topLeading)
                        .padding(.horizontal, 20)
                        .offset(x: CGFloat(offset) * geometry.size.width + dragOffset)
                }
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height - 100)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            TapGesture()
                .onEnded { _ in
                    withAnimation {
                        showSettings.toggle()
                    }
                }
        )
    }
    
    private var settingsPanel: some View {
        VStack {
            Spacer()
            HStack {
                Button(action: { showChapterList.toggle() }) {
                    VStack {
                        Image(systemName: "list.bullet")
                        Text("目录")
                    }
                }
                Spacer()
                Button(action: { isDarkMode.toggle() }) {
                    VStack {
                        Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        Text("夜晚")
                    }
                }
                Spacer()
                Button(action: { showFontSettings.toggle() }) {
                    VStack {
                        Image(systemName: "textformat")
                        Text("设置")
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 5)
        }
        .transition(.move(edge: .bottom))
    }
    
    private var chapterListView: some View {
        VStack {
            HStack {
                Text("章节列表")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    showChapterList = false
                }
            }
            .padding()
            
            List(bookLoader.book?.chapters.indices ?? 0..<0, id: \.self) { index in
                Button(action: {
                    chapterIndex = index
                    loadChapterContent(for: bookLoader.book!)
                    showChapterList = false
                }) {
                    Text(bookLoader.book?.chapters[index].title ?? "")
                        .foregroundColor(index == chapterIndex ? .blue : .primary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
    }
    
    private var fontSettingsView: some View {
        VStack {
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    showFontSettings = false
                    splitContentIntoPages() // Re-split pages when closing settings
                }
            }
            .padding()
            
            VStack(alignment: .leading, spacing: 20) {
                Text("字体大小")
                Slider(value: $fontSize, in: 12...32, step: 1) {
                    Text("Font Size")
                }
                
                Text("字体")
                Picker("Font Family", selection: $fontFamily) {
                    Text("Georgia").tag("Georgia")
                    Text("Helvetica").tag("Helvetica")
                    Text("Times New Roman").tag("Times New Roman")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
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
        let font = UIFont(name: fontFamily, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        
        pages = BookUtils.splitContentIntoPages(content: content, size: contentSize, font: font, lineSpacing: lineSpacing)
        totalPages = pages.count
        currentPage = min(currentPage, totalPages - 1) // Ensure current page is within bounds
    }
    
    private func nextPage() {
        withAnimation {
            if currentPage < totalPages - 1 {
                currentPage += 1
            } else if chapterIndex < (bookLoader.book?.chapters.count ?? 0) - 1 {
                chapterIndex += 1
                currentPage = 0
                loadChapterContent(for: bookLoader.book!)
            }
        }
    }
    
    private func previousPage() {
        withAnimation {
            if currentPage > 0 {
                currentPage -= 1
            } else if chapterIndex > 0 {
                chapterIndex -= 1
                loadChapterContent(for: bookLoader.book!)
                currentPage = totalPages - 1
            }
        }
    }
}

struct BookReadingView_Previews: PreviewProvider {
    static var previews: some View {
        BookReadingView(baseURL: "https://www.bqgda.cc/", bookURL: "https://www.bqgda.cc/books/9680/")
    }
}
