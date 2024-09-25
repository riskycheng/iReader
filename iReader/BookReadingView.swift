import SwiftUI
import SwiftSoup

struct BookReadingView: View {
    @StateObject private var viewModel: BookReadingViewModel
    @Binding var isPresented: Bool
    @State private var pageTurningMode: PageTurningMode = .bezier
    @State private var isParsing: Bool = true
    @State private var parsingProgress: Double = 0
    @State private var showSettingsPanel: Bool = false
    @State private var showSecondLevelSettings: Bool = false
    
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
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.pages.isEmpty {
                    emptyContentView
                } else {
                    bookContent(in: geometry)
                        .gesture(
                            TapGesture()
                                .onEnded { _ in
                                    if showSecondLevelSettings {
                                        showSecondLevelSettings = false
                                        showSettingsPanel = false
                                    } else {
                                        showSettingsPanel.toggle()
                                    }
                                }
                        )
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
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("正在解析章节...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("请稍候，马上就好")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(String(format: "%.0f%%", min(self.parsingProgress * 100, 100.0)))
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(15)
        }
    }
    
    private var loadingView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("正在加载章节...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(15)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                Text("加载出错")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(15)
        }
    }
    
    private var emptyContentView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "book.closed")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                
                Text("暂无内容")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("请稍后再试")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(15)
        }
    }
    
    private func bookContent(in geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottom) {
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
                    mode: viewModel.pageTurningMode,
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
                .background(viewModel.backgroundColor)
                
                Spacer(minLength: 0)
                
                // Bottom Toolbar
                bottomToolbar
                    .frame(height: 30)
                    .background(Color(.systemBackground).opacity(0.8))
            }
            
            settingsOverlay(in: geometry)
        }
    }
    
    private func settingsOverlay(in geometry: GeometryProxy) -> some View {
        Group {
            if showSecondLevelSettings {
                secondLevelSettingsPanel
            } else {
                settingsPanel
            }
        }
        .frame(height: 150) // 调整为实际菜单高度
        .frame(maxWidth: .infinity)
        .background(Color(UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)))
        .offset(y: showSettingsPanel ? 0 : geometry.size.height)
        .animation(.none) // 禁用所有动画
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
        VStack(spacing: 20) {
            // 第一行：章节切换和进度滑块
            HStack {
                Button(action: { viewModel.previousChapter() }) {
                    Text("上一章")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                }
                CustomSlider(value: $viewModel.chapterProgress, range: 0...1) { _ in
                    viewModel.updateCurrentPageFromProgress()
                }
                Button(action: { viewModel.nextChapter() }) {
                    Text("下一章")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // 第二行：目录、夜间模式和设置
            HStack {
                Button(action: { viewModel.showChapterList.toggle() }) {
                    VStack {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 24))
                        Text("目录")
                            .font(.system(size: 16))
                    }
                }
                Spacer()
                Button(action: {
                    viewModel.isDarkMode.toggle()
                    viewModel.objectWillChange.send()
                }) {
                    VStack {
                        Image(systemName: viewModel.isDarkMode ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 24))
                        Text("夜间")
                            .font(.system(size: 16))
                    }
                }
                Spacer()
                Button(action: {
                    showSecondLevelSettings = true
                }) {
                    VStack {
                        Image(systemName: "textformat")
                            .font(.system(size: 24))
                        Text("设置")
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 10)
            .foregroundColor(.black)
        }
    }
    
    private var secondLevelSettingsPanel: some View {
        VStack(spacing: 20) {
            // 亮度滑块
            HStack {
                Image(systemName: "sun.min")
                Slider(value: .constant(0.5))
                Image(systemName: "sun.max")
            }
            .padding(.horizontal)
            
            // 字体大小和翻页模式
            HStack {
                Button(action: { viewModel.fontSize -= 1 }) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                
                Menu {
                    Picker("字体大小", selection: $viewModel.fontSize) {
                        ForEach(8...32, id: \.self) { size in
                            Text("\(size)").tag(CGFloat(size))
                        }
                    }
                } label: {
                    HStack {
                        Text("\(Int(viewModel.fontSize))")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 60)
                
                Button(action: { viewModel.fontSize += 1 }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Menu {
                    ForEach(BookReadingViewModel.allPageTurningModes, id: \.self) { mode in
                        Button(action: {
                            viewModel.pageTurningMode = mode
                        }) {
                            HStack {
                                Text(viewModel.displayName(for: mode))
                                Spacer()
                                if viewModel.pageTurningMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.pageTurningModeDisplayName)
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(5)
                }
            }
            .padding(.horizontal)
            
            // 背景颜色选择
            GeometryReader { geometry in
                HStack(spacing: 10) {
                    ForEach(viewModel.backgroundColors, id: \.self) { color in
                        Button(action: { viewModel.backgroundColor = color }) {
                            color
                                .frame(width: (geometry.size.width - 30) / CGFloat(viewModel.backgroundColors.count))
                                .frame(height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(viewModel.backgroundColor == color ? Color.black : Color.clear, lineWidth: 2)
                                )
                                .cornerRadius(5)
                        }
                    }
                }
            }
            .frame(height: 40)
            .padding(.horizontal)
        }
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
                        Picker("Page Turning Mode", selection: $viewModel.pageTurningMode) {
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
        @Published var chapterProgress: Double = 0
        @Published var backgroundColor: Color = .white
        @Published var pageTurningMode: PageTurningMode = .bezier
        @Published var backgroundColors: [Color] = [.white, Color(UIColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1.0)), Color(UIColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 1.0)), .black]
        
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
                
                let newChapters = try chapterElements.enumerated().compactMap { index, element -> Book.Chapter? in
                    let title = try element.text()
                    let link = try element.attr("href")
                    
                    // Filter out the "展开全部章节" chapter
                    guard !title.contains("展开全部章节") else {
                        return nil
                    }
                    
                    let fullLink = "https://www.bqgda.cc" + link
                    
                    // Update progress
                    DispatchQueue.main.async {
                        progressUpdate(Double(index + 1) / Double(totalChapters))
                    }
                    
                    return Book.Chapter(title: title, link: fullLink)
                }
                
                // Update the book chapters on the main actor
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
            updateProgressFromCurrentPage()
        }
        
        func nextPage() {
            if currentPage < totalPages - 1 {
                currentPage += 1
            } else if chapterIndex < book.chapters.count - 1 {
                loadChapter(at: chapterIndex + 1)
            }
            updateProgressFromCurrentPage()
        }
        
        func previousPage() {
            if currentPage > 0 {
                currentPage -= 1
            } else if chapterIndex > 0 {
                loadChapter(at: chapterIndex - 1)
                currentPage = totalPages - 1
            }
            updateProgressFromCurrentPage()
        }
        
        func nextChapter() {
            if chapterIndex < book.chapters.count - 1 {
                chapterIndex += 1
                loadChapter(at: chapterIndex)
            }
            updateProgressFromCurrentPage()
        }
        
        func previousChapter() {
            if chapterIndex > 0 {
                chapterIndex -= 1
                loadChapter(at: chapterIndex)
            }
            updateProgressFromCurrentPage()
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
        
        func updateCurrentPageFromProgress() {
            let newPage = Int(chapterProgress * Double(totalPages - 1))
            currentPage = newPage
        }
        
        func updateProgressFromCurrentPage() {
            chapterProgress = Double(currentPage) / Double(max(totalPages - 1, 1))
        }
        
        var pageTurningModeDisplayName: String {
            displayName(for: pageTurningMode)
        }
        
        static let allPageTurningModes: [PageTurningMode] = [.bezier, .horizontal, .direct]
        
        func displayName(for mode: PageTurningMode) -> String {
            switch mode {
            case .bezier:
                return "覆盖"
            case .horizontal:
                return "仿真"
            case .direct:
                return "上下"
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
