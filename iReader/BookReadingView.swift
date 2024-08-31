import SwiftUI
import SwiftSoup

struct BookReadingView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: BookReadingViewModel
    
    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookReadingViewModel(book: book))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading chapter...")
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                } else {
                    bookContent(in: geometry)
                }
                
                if viewModel.showSettings {
                    settingsPanel
                }
                
                if viewModel.showChapterList {
                    chapterListView
                }
                
                if viewModel.showFontSettings {
                    fontSettingsView
                }
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
    }
    
    private func bookContent(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top Bar with Book Name and Chapter Name
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(viewModel.book.title)
                    }
                    .font(.headline)
                }
                Spacer()
                Text(viewModel.currentChapterTitle)
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 5)
            
            // Content Display
            if !viewModel.pages.isEmpty {
                pageContent(in: geometry)
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
                Text("\(viewModel.currentPage + 1) / \(viewModel.totalPages)")
            }
            .font(.footnote)
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
    
    private func pageContent(in geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach([-1, 0, 1], id: \.self) { offset in
                let pageIndex = viewModel.currentPage + offset
                if pageIndex >= 0 && pageIndex < viewModel.pages.count {
                    Text(viewModel.pages[pageIndex])
                        .font(.custom(viewModel.fontFamily, size: viewModel.fontSize))
                        .lineSpacing(viewModel.lineSpacing)
                        .frame(width: geometry.size.width - 40, height: geometry.size.height - 100, alignment: .topLeading)
                        .padding(.horizontal, 20)
                        .offset(x: CGFloat(offset) * geometry.size.width + viewModel.dragOffset)
                }
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height - 100)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    viewModel.dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold = geometry.size.width * 0.2
                    if value.translation.width > threshold {
                        viewModel.previousPage()
                    } else if value.translation.width < -threshold {
                        viewModel.nextPage()
                    }
                    viewModel.dragOffset = 0
                }
        )
        .gesture(
            TapGesture()
                .onEnded { _ in
                    withAnimation {
                        viewModel.showSettings.toggle()
                    }
                }
        )
    }
    
    private var settingsPanel: some View {
        VStack {
            Spacer()
            HStack {
                Button(action: { viewModel.showChapterList.toggle() }) {
                    VStack {
                        Image(systemName: "list.bullet")
                        Text("目录")
                    }
                }
                Spacer()
                Button(action: { viewModel.isDarkMode.toggle() }) {
                    VStack {
                        Image(systemName: viewModel.isDarkMode ? "moon.fill" : "sun.max.fill")
                        Text("夜晚")
                    }
                }
                Spacer()
                Button(action: { viewModel.showFontSettings.toggle() }) {
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
                    viewModel.showChapterList = false
                }
            }
            .padding()
            
            List(viewModel.book.chapters.indices, id: \.self) { index in
                Button(action: {
                    viewModel.chapterIndex = index
                    viewModel.loadChapterContent()
                    viewModel.showChapterList = false
                }) {
                    Text(viewModel.book.chapters[index].title)
                        .foregroundColor(index == viewModel.chapterIndex ? .blue : .primary)
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
                    viewModel.showFontSettings = false
                    viewModel.splitContentIntoPages(viewModel.currentChapterContent)
                }
            }
            .padding()
            
            VStack(alignment: .leading, spacing: 20) {
                Text("字体大小")
                Slider(value: $viewModel.fontSize, in: 12...32, step: 1) {
                    Text("Font Size")
                }
                
                Text("字体")
                Picker("Font Family", selection: $viewModel.fontFamily) {
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
}

class BookReadingViewModel: ObservableObject {
    @Published var book: Book
    @Published var currentPage: Int = 0
    @Published var totalPages: Int = 1
    @Published var pages: [String] = []
    @Published var chapterIndex: Int = 0
    @Published var showSettings: Bool = false
    @Published var showChapterList: Bool = false
    @Published var showFontSettings: Bool = false
    @Published var isDarkMode: Bool = false
    @Published var fontSize: CGFloat = 20
    @Published var fontFamily: String = "Georgia"
    @Published var dragOffset: CGFloat = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    let lineSpacing: CGFloat = 8
    var currentChapterContent: String = ""
    
    init(book: Book) {
        self.book = book
        loadChapterContent()
    }
    
    var currentChapterTitle: String {
        book.chapters[chapterIndex].title
    }
    
    func loadChapterContent() {
        isLoading = true
        errorMessage = nil
        
        guard chapterIndex < book.chapters.count else {
            errorMessage = "Invalid chapter index"
            isLoading = false
            return
        }
        
        let chapterURL = book.chapters[chapterIndex].link
        
        Task {
            do {
                let content = try await fetchChapterContent(from: chapterURL)
                await MainActor.run {
                    currentChapterContent = content
                    splitContentIntoPages(content)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func fetchChapterContent(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ChapterParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to convert data to string"])
        }
        
        let doc = try SwiftSoup.parse(html)
        let content = try doc.select("div#chaptercontent").text()
        return content
    }
    
    func splitContentIntoPages(_ content: String) {
        let screenSize = UIScreen.main.bounds.size
        let contentSize = CGSize(width: screenSize.width - 40, height: screenSize.height - 100)
        let font = UIFont(name: fontFamily, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        
        pages = BookUtils.splitContentIntoPages(content: content, size: contentSize, font: font, lineSpacing: lineSpacing)
        totalPages = pages.count
        currentPage = min(currentPage, totalPages - 1)
    }
    
    func nextPage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        } else if chapterIndex < book.chapters.count - 1 {
            chapterIndex += 1
            currentPage = 0
            loadChapterContent()
        }
    }
    
    func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
        } else if chapterIndex > 0 {
            chapterIndex -= 1
            loadChapterContent()
            currentPage = totalPages - 1
        }
    }
}

struct BookReadingView_Previews: PreviewProvider {
    static var previews: some View {
        BookReadingView(book: Book(
            title: "Sample Book",
            author: "Sample Author",
            coverURL: "",
            lastUpdated: "",
            status: "",
            introduction: "",
            chapters: [Book.Chapter(title: "Chapter 1", link: "")],
            link: ""
        ))
    }
}
