import SwiftUI
import SwiftSoup

struct BookReadingView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: BookReadingViewModel
    @State private var dragOffset: CGFloat = 0
    
    init(book: Book) {
            // Initialize the ViewModel on the main thread
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
            .onAppear {
                // Ensure initial loading is done on the main thread
                DispatchQueue.main.async {
                    viewModel.initializeBook()
                }
            }
        }
    
    private func bookContent(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top Bar
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
            pageContent(in: geometry)
            
            // Bottom Toolbar
            HStack {
                HStack {
                    Image(systemName: "battery.100")
                    Text("100%")
                }
                Spacer()
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
                pageView(for: viewModel.currentPage + offset, in: geometry)
                    .offset(x: CGFloat(offset) * geometry.size.width + dragOffset)
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height - 100)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold = geometry.size.width * 0.2
                    withAnimation(.easeOut(duration: 0.2)) {
                        if value.translation.width > threshold {
                            viewModel.previousPage()
                        } else if value.translation.width < -threshold {
                            viewModel.nextPage()
                        }
                        dragOffset = 0
                    }
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
    
    private func pageView(for index: Int, in geometry: GeometryProxy) -> some View {
        Group {
            if index >= 0 && index < viewModel.pages.count {
                Text(viewModel.pages[index])
                    .font(.custom(viewModel.fontFamily, size: viewModel.fontSize))
                    .lineSpacing(viewModel.lineSpacing)
                    .frame(width: geometry.size.width - 40, height: geometry.size.height - 100, alignment: .topLeading)
                    .padding(.horizontal, 20)
            } else {
                Color.clear
            }
        }
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
                    viewModel.loadChapter(at: index)
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
    }
    
    func initializeBook() {
        Task {
            await loadAllChapters()
            loadChapter(at: 0)
        }
    }
    
    var currentChapterTitle: String {
        guard chapterIndex < book.chapters.count else { return "Unknown Chapter" }
        return book.chapters[chapterIndex].title
    }
    
    func loadAllChapters() async {
        do {
            guard let url = URL(string: book.link) else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "ChapterParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to convert data to string"])
            }
            
            let doc = try SwiftSoup.parse(html)
            let chapterElements = try doc.select(".listmain dd a")
            
            let newChapters: [Book.Chapter] = try chapterElements.map { element in
                let title = try element.text()
                let link = try element.attr("href")
                let fullLink = "https://www.bqgda.cc" + link
                return Book.Chapter(title: title, link: fullLink)
            }
            
            await MainActor.run {
                self.book.chapters = newChapters
                self.isLoading = false
                self.cacheUpdatedBook()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func loadChapter(at index: Int) {
        guard index < book.chapters.count else {
            errorMessage = "Invalid chapter index"
            return
        }
        
        chapterIndex = index
        currentPage = 0  // Reset the current page to 0 when loading a new chapter
        
        Task {
            await loadChapterContent()
        }
    }
    
    func loadChapterContent() async {
        do {
            guard chapterIndex < book.chapters.count else {
                throw NSError(domain: "ChapterError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid chapter index"])
            }
            
            let chapterURL = book.chapters[chapterIndex].link
            let content = try await fetchChapterContent(from: chapterURL)
            
            await MainActor.run {
                self.currentChapterContent = content
                self.splitContentIntoPages(content)
                self.currentPage = 0
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
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
        let content = try doc.select("div#chaptercontent").html()
        return cleanHTML(content)
    }
    
    private func cleanHTML(_ html: String) -> String {
        var cleanedContent = html
        
        // Replace all <br>, <br/>, or <br /> tags with a special placeholder
        let brRegex = try! NSRegularExpression(pattern: "<br\\s*/?>", options: [.caseInsensitive])
        cleanedContent = brRegex.stringByReplacingMatches(in: cleanedContent, options: [], range: NSRange(location: 0, length: cleanedContent.utf16.count), withTemplate: "")
        
        //           // Decode HTML entities
        cleanedContent = cleanedContent.replacingOccurrences(of: "&nbsp;", with: " ")
        cleanedContent = cleanedContent.replacingOccurrences(of: "&lt;", with: "<")
        cleanedContent = cleanedContent.replacingOccurrences(of: "&gt;", with: ">")
        cleanedContent = cleanedContent.replacingOccurrences(of: "&amp;", with: "&")
        cleanedContent = cleanedContent.replacingOccurrences(of: "&quot;", with: "\"")
        cleanedContent = cleanedContent.replacingOccurrences(of: "&#39;", with: "'")
        
        // Replace multiple spaces with a single space
        //           let multipleSpacesRegex = try! NSRegularExpression(pattern: "\\s{2,}", options: [])
        //           cleanedContent = multipleSpacesRegex.stringByReplacingMatches(in: cleanedContent, options: [], range: NSRange(location: 0, length: cleanedContent.utf16.count), withTemplate: "\n")
        
        return cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    
    func splitContentIntoPages(_ content: String) {
        let screenSize = UIScreen.main.bounds.size
        let contentSize = CGSize(width: screenSize.width - 40, height: screenSize.height - 120) // Adjusted for top and bottom bars
        let font = UIFont(name: fontFamily, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        
        let attributedString = NSAttributedString(
            string: content,
            attributes: [
                .font: font,
                NSAttributedString.Key.paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = lineSpacing
                    return style
                }()
            ]
        )
        
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: CGRect(origin: .zero, size: contentSize), transform: nil)
        
        var pages: [String] = []
        var currentIndex = 0
        
        while currentIndex < attributedString.length {
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(currentIndex, 0), path, nil)
            let range = CTFrameGetVisibleStringRange(frame)
            
            if range.length == 0 {
                break
            }
            
            let pageContent = (attributedString.string as NSString).substring(with: NSRange(location: range.location, length: range.length))
            pages.append(pageContent)
            
            currentIndex += range.length
        }
        
        self.pages = pages
        totalPages = pages.count
        currentPage = min(currentPage, totalPages - 1)
    }
    
    func nextPage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        } else if chapterIndex < book.chapters.count - 1 {
            loadChapter(at: chapterIndex + 1)
        }
    }
    
    func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
        } else if chapterIndex > 0 {
            loadChapter(at: chapterIndex - 1)
            currentPage = totalPages - 1
        }
    }
    
    private func cacheUpdatedBook() {
        // Implement caching logic here, e.g., using UserDefaults or a database
        // This is a placeholder implementation
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(book)
            UserDefaults.standard.set(data, forKey: "cachedBook_\(book.id)")
        } catch {
            print("Error caching updated book: \(error)")
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
