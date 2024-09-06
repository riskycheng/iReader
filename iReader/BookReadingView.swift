import SwiftUI
import SwiftSoup

import SwiftUI

struct BookReadingView: View {
    @StateObject private var viewModel: BookReadingViewModel
    @Binding var isPresented: Bool
    @State private var pageTurningMode: PageTurningMode = .bezier
    @State private var isParsing: Bool = true
    @State private var parsingProgress: Double = 0
    @State private var showSettingsPanel: Bool = false
    
    init(book: Book, isPresented: Binding<Bool>) {
        print("BookReadingView initialized with book: \(book.title)")
        _viewModel = StateObject(wrappedValue: BookReadingViewModel(book: book))
        _isPresented = isPresented
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isParsing {
                    parsingView
                } else if viewModel.isLoading {
                    ProgressView("Loading chapter...")
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                } else if viewModel.pages.isEmpty {
                    Text("No content available")
                        .foregroundColor(.red)
                } else {
                    bookContent(in: geometry)
                }
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
        .onAppear {
            DispatchQueue.main.async {
                viewModel.initializeBook { progress in
                    self.parsingProgress = progress
                    if progress >= 1.0 {
                        withAnimation {
                            self.isParsing = false
                        }
                    }
                }
            }
        }
        .overlay(
            Group {
                if viewModel.showChapterList {
                    chapterListView
                }
                if viewModel.showFontSettings {
                    fontSettingsView
                }
            }
        )
    }
    
    
    
    private var parsingView: some View {
        VStack(spacing: 20) {
            Text("Parsing chapters...")
                .font(.headline)
            
            Text("Wait, ready soon.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(lineWidth: 8.0)
                    .opacity(0.3)
                    .foregroundColor(Color.blue)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(self.parsingProgress, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 8.0, lineCap: .round, lineJoin: .round))
                    .foregroundColor(Color.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: parsingProgress)
                
                Text(String(format: "%.0f%%", min(self.parsingProgress * 100, 100.0)))
                    .font(.headline)
                    .bold()
            }
            .frame(width: 100, height: 100)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity) // This centers the VStack
        .background(Color.black.opacity(0.3)) // Semi-transparent background
        .edgesIgnoringSafeArea(.all)
    }
    
    func bookContent(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Button(action: {
                    isPresented = false
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
            PageTurningView(
                mode: pageTurningMode,
                currentPage: $viewModel.currentPage,
                totalPages: viewModel.totalPages,
                onPageChange: { newPage in
                    viewModel.currentPage = newPage
                },
                onNextChapter: {
                    viewModel.nextChapter()
                },
                onPreviousChapter: {
                    viewModel.previousChapter()
                }
            ) {
                pageContent(in: geometry)
            }
            .frame(height: geometry.size.height - 80)
            
            Spacer(minLength: 0)
            
            // Bottom Toolbar
            bottomToolbar
                .frame(height: 30)
                .background(Color(.systemBackground).opacity(0.8))
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    withAnimation {
                        showSettingsPanel.toggle()
                    }
                }
        )
        .overlay(
            Group {
                if showSettingsPanel {
                    settingsPanel
                }
            }
        )
    }
    
    private var bottomToolbar: some View {
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
    }
    
    private func pageContent(in geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach([-1, 0, 1], id: \.self) { offset in
                pageView(for: viewModel.currentPage + offset, in: geometry)
                    .offset(x: CGFloat(offset) * geometry.size.width)
            }
        }
    }
    
    private func pageView(for index: Int, in geometry: GeometryProxy) -> some View {
        Group {
            if index >= 0 && index < viewModel.pages.count {
                ScrollView {
                    Text(viewModel.pages[index])
                        .font(.custom(viewModel.fontFamily, size: viewModel.fontSize))
                        .lineSpacing(viewModel.lineSpacing)
                        .frame(width: geometry.size.width - 40, alignment: .topLeading)
                        .padding(.horizontal, 20)
                }
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
                Button(action: {
                    viewModel.isDarkMode.toggle()
                    viewModel.objectWillChange.send()
                }) {
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
    
    var chapterListView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Color(.systemBackground)
                    .frame(height: geometry.safeAreaInsets.top)
                
                HStack {
                    Text("章节列表")
                        .font(.headline)
                    Spacer()
                    Button("关闭") {
                        viewModel.showChapterList = false
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
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
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    var fontSettingsView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Color(.systemBackground)
                    .frame(height: geometry.safeAreaInsets.top)
                
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
                .background(Color(.systemBackground))
                
                Form {
                    Section(header: Text("字体大小")) {
                        Slider(value: $viewModel.fontSize, in: 12...32, step: 1) { _ in
                            viewModel.splitContentIntoPages(viewModel.currentChapterContent)
                        }
                    }
                    
                    Section(header: Text("字体")) {
                        Picker("Font Family", selection: $viewModel.fontFamily) {
                            Text("Georgia").tag("Georgia")
                            Text("Helvetica").tag("Helvetica")
                            Text("Times New Roman").tag("Times New Roman")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: viewModel.fontFamily) { _ in
                            viewModel.splitContentIntoPages(viewModel.currentChapterContent)
                        }
                    }
                    
                    Section(header: Text("翻页模式")) {
                        Picker("Page Turning Mode", selection: $pageTurningMode) {
                            Text("贝塞尔曲线").tag(PageTurningMode.bezier)
                            Text("水平滑动").tag(PageTurningMode.horizontal)
                            Text("直接切换").tag(PageTurningMode.direct)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
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
            print("BookReadingViewModel initialized with book: \(book.title)")
        }
        
        func initializeBook(progressUpdate: @escaping (Double) -> Void) {
            print("Initializing book: \(book.title)")
            Task {
                await loadAllChapters(progressUpdate: progressUpdate)
                loadChapter(at: 0)
            }
        }
        
        var currentChapterTitle: String {
            guard chapterIndex < book.chapters.count else { return "Unknown Chapter" }
            return book.chapters[chapterIndex].title
        }
        
        func loadAllChapters(progressUpdate: @escaping (Double) -> Void) async {
            print("Loading all chapters for book: \(book.title)")
            
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
                
                let totalChapters = chapterElements.count
                
                let newChapters = try await chapterElements.enumerated().asyncMap { index, element -> Book.Chapter in
                    let title = try element.text()
                    let link = try element.attr("href")
                    let fullLink = "https://www.bqgda.cc" + link
                    
                    let progress = Double(index + 1) / Double(totalChapters)
                    await MainActor.run {
                        progressUpdate(progress)
                    }
                    
                    return Book.Chapter(title: title, link: fullLink)
                }
                
                // Update the book chapters on the main actor
                await MainActor.run { [newChapters] in
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
            print("Loading chapter at index: \(index)")
            
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
            print("Loading chapter content")
            
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
            let contentElement = try doc.select("div#chaptercontent").first()
            
            // Remove unwanted elements
            try contentElement?.select("p.readinline").remove()
            
            // Get the HTML content
            var content = try contentElement?.html() ?? ""
            
            // Remove content starting with "<br>请收藏本站"
            if let range = content.range(of: "请收藏本站") {
                content = String(content[..<range.lowerBound])
            }
            
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
            print("Splitting content into pages. Content length: \(content.count)")
            
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
            print("Pages after splitting: \(pages.count)")
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
        
        func nextChapter() {
            if chapterIndex < book.chapters.count - 1 {
                chapterIndex += 1
                loadChapter(at: chapterIndex)
            }
        }
        
        func previousChapter() {
            if chapterIndex > 0 {
                chapterIndex -= 1
                loadChapter(at: chapterIndex)
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
            BookReadingView(
                book: Book(
                    title: "Sample Book",
                    author: "Sample Author",
                    coverURL: "",
                    lastUpdated: "",
                    status: "",
                    introduction: "",
                    chapters: [Book.Chapter(title: "Chapter 1", link: "")],
                    link: ""
                ),
                isPresented: .constant(true)
            )
        }
    }
}

extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            try await values.append(transform(element))
        }
        return values
    }
}
