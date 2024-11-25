import SwiftUI
import SwiftSoup

class BookReadingViewModel: ObservableObject {
        @Published var book: Book
        @Published var currentPage: Int = 0
        @Published var totalPages: Int = 1
        @Published var pages: [String] = []
        @Published var chapterIndex: Int = 0
        @Published var showSettings: Bool = false
        @Published var showChapterList: Bool = false
        @Published var showFontSettings: Bool = false
        @Published var isChapterListReversed: Bool = false
        @Published var isDarkMode: Bool = false {
            didSet {
                updateColorScheme()
            }
        }
        @Published private(set) var fontSize: CGFloat = 20
        @Published var fontFamily: String = "Georgia"
        @Published var dragOffset: CGFloat = 0
        @Published var isLoading: Bool = false
        @Published var errorMessage: String?
        @Published var chapterProgress: Double = 0
        @Published var backgroundColor: Color = .white
        @Published var menuBackgroundColor: Color = Color(UIColor.systemGray6)
        @Published var textColor: Color = .black
        @Published var pageTurningMode: PageTurningMode = .curl
        @Published var backgroundColors: [Color] = [.white, Color(UIColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1.0)), Color(UIColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 1.0)), .black]
        @Published var brightness: Double = Double(UIScreen.main.brightness) {
            didSet {
                UIScreen.main.brightness = CGFloat(brightness)
            }
        }
        
        let lineSpacing: CGFloat = 8
        var currentChapterContent: String = ""
        
        // 新增一个属性，用于标记章节是否正在加载
        @Published var isChapterLoading: Bool = false
        
        @Published var nextChapterTitle: String = "" // 新增属性
        
        // 新增属性
        private let userDefaults = UserDefaults.standard
        
        // 保持 initialLoad 为私有
        private var initialLoad: Bool = true
        
        @Published var isChapterTransitioning: Bool = false
        
        @Published var isLoadingPreviousChapter = false
        
        @Published var isLoadingNextChapter = false
        
        private let preloadChapterCount = 5
        private var preloadedChapters: [Int: String] = [:] // 缓存预加载的章节内容
        @AppStorage("autoPreload") private var autoPreload = true // 从 UserDefaults 读设置
        
        // 字体结构体
        struct FontOption: Identifiable, Hashable {
            let id = UUID()
            let name: String      // 显示名称
            let fontName: String  // 实际字体名称
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(id)
            }
            
            static func == (lhs: FontOption, rhs: FontOption) -> Bool {
                lhs.id == rhs.id
            }
        }
        
        // 可用字体列表
        let availableFonts: [FontOption] = [
            FontOption(name: "苹", fontName: "PingFang SC"),
            FontOption(name: "黑体", fontName: "Heiti SC"),
            FontOption(name: "细黑体", fontName: "STHeitiSC-Light"),
            FontOption(name: "宋体", fontName: "STSong"),
            FontOption(name: "乔治亚", fontName: "Georgia")
        ]
        
        // 修改字体属性为 FontOption
        @Published var currentFont: FontOption {
            didSet {
                fontFamily = currentFont.fontName
            }
        }
        
        // 初始化时设置默认字体
        init(book: Book, startingChapter: Int = 0) {
            print("BookReadingViewModel initialized with book: \(book.title), startingChapter: \(startingChapter)")
            self.book = book
            self.chapterIndex = startingChapter
            
            // 初始化默认字体
            let defaultFont = FontOption(name: "苹方", fontName: "PingFang SC")
            self.currentFont = defaultFont
            self.fontFamily = defaultFont.fontName
        }
        
        func initializeBook(progressCallback: @escaping (Double) -> Void) {
            print("Initializing book: \(book.title)")
            Task {
                await loadAllChapters(progressUpdate: progressCallback)
                
                // 直接加载用户选择的章节
                await MainActor.run {
                    loadChapter(at: chapterIndex, resetPage: true)
                    preloadNextChapters()
                }
                
                progressCallback(1.0)
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
        
        func loadChapter(at index: Int, resetPage: Bool = true) {
            print("loadChapter called. Index: \(index), resetPage: \(resetPage)")
            guard index >= 0 && index < book.chapters.count else { return }
            
            isChapterLoading = true
            chapterIndex = index
            
            // 使用预加载的内容而不是缓存
            if let preloadedContent = preloadedChapters[index] {
                Task { @MainActor in  // 确保在 MainActor 上行 UI 更新
                    currentChapterContent = preloadedContent
                    splitContentIntoPages(preloadedContent)
                    isChapterLoading = false
                    if resetPage {
                        currentPage = 0
                    }
                    // 清理已使用的预加载内容
                    preloadedChapters.removeValue(forKey: index)
                    // 触发新的预加载
                    preloadNextChapters()
                }
            } else {
                Task {
                    await loadChapterContent()
                    await MainActor.run {
                        self.isChapterLoading = false
                        if resetPage {
                            self.currentPage = 0
                        }
                        self.updateProgressFromCurrentPage()
                        self.saveReadingProgress()
                        self.initialLoad = false
                        print("正常加载完成：第 \(index + 1) 章")
                    }
                    // 加载完成后触发预加载
                    preloadNextChapters()
                }
            }
        }
        
        // 新增方法：从章节列表加载章节
        func loadChapterFromList(at index: Int) {
            loadChapter(at: index, resetPage: true)
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
            
            // 移除所有广告和推荐内容
            try contentElement?.select("p.readinline").remove()
            try contentElement?.select("div.content_detail").remove()
            try contentElement?.select("div.bottem").remove()
            try contentElement?.select("script").remove()
            
            // 获取HTML内容并进行处理
            var processedContent = try contentElement?.html() ?? ""
            
            // 移除开头的新书推荐部分（包括整个段落）
            if let range = processedContent.range(of: "新书推荐：") {
                if let endRange = processedContent[range.upperBound...].range(of: "\n\n") {
                    processedContent = String(processedContent[endRange.upperBound...])
                }
            }
            
            // 移除结尾的请收藏本站内容（包括整个段落）
            if let range = processedContent.range(of: "请收藏本站") {
                if let startRange = processedContent[..<range.lowerBound].lastIndex(of: "\n") {
                    processedContent = String(processedContent[..<startRange])
                }
            }
            
            // 清理HTML并格式化段落
            processedContent = cleanHTML(processedContent)
            
            // 获取当前章节标题用于过滤
            let currentChapterTitle = book.chapters[chapterIndex].title
            
            let paragraphs = processedContent
                .components(separatedBy: "\n")
                .map { paragraph in 
                    paragraph.trimmingCharacters(in: .whitespacesAndNewlines) 
                }
                .filter { paragraph in 
                    !paragraph.isEmpty &&
                    !paragraph.contains("新书推荐") &&
                    !paragraph.contains("笔趣阁") &&
                    !paragraph.contains("请收藏") &&
                    paragraph.count >= 2 &&
                    // 过滤掉章节标题
                    !paragraph.contains(currentChapterTitle) &&
                    // 过滤掉任何形式的章节标题（比如"第X章"）
                    !(paragraph.hasPrefix("第") && paragraph.contains("章"))
                }
                .map { paragraph in
                    // 普通段落添加缩进
                    return "　　\(paragraph)"
                }
            
            // 使用双换行符连接段落
            return paragraphs.joined(separator: "\n\n")
        }
        
        private func cleanHTML(_ html: String) -> String {
            var cleanedContent = html
            
            // 替换HTML标签为适当的换行符
            let tagPatterns = [
                "<br.*?>": "\n",
                "<p.*?>": "\n",
                "</p>": "\n",
                "<div.*?>": "\n",
                "</div>": "\n",
                "<.*?>": "" // 移除其他所有HTML标签
            ]
            
            for (pattern, replacement) in tagPatterns {
                cleanedContent = cleanedContent.replacingOccurrences(
                    of: pattern,
                    with: replacement,
                    options: .regularExpression
                )
            }
            
            // 解码HTML实体
            let htmlEntities = [
                "&nbsp;": " ",
                "&lt;": "<",
                "&gt;": ">",
                "&amp;": "&",
                "&quot;": "\"",
                "&#39;": "'",
                "&ldquo;": "\"",
                "&rdquo;": "\"",
                "&hellip;": "…"
            ]
            
            for (entity, replacement) in htmlEntities {
                cleanedContent = cleanedContent.replacingOccurrences(of: entity, with: replacement)
            }
            
            // 规范化空白字符，但保留段落格式
            cleanedContent = cleanedContent
                .replacingOccurrences(of: " +", with: " ", options: .regularExpression)  // 合并多个空格
                .replacingOccurrences(of: "\n\\s+", with: "\n", options: .regularExpression)  // 清理行首空白
                .replacingOccurrences(of: "\\s+\n", with: "\n", options: .regularExpression)  // 清理行尾空白
                .replacingOccurrences(of: "\n{4,}", with: "\n\n\n", options: .regularExpression)  // 最多保留三个连续换行
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return cleanedContent
        }
        
        @MainActor
        func splitContentIntoPages(_ content: String) {
            let screenSize = UIScreen.main.bounds.size
            let headerHeight: CGFloat = 40
            let footerHeight: CGFloat = 20
            let horizontalPadding: CGFloat = 20
            let topPadding: CGFloat = 10
            let bottomPadding: CGFloat = 10
            let chapterTitleHeight: CGFloat = 60  // 章节标题的高度
            
            // 配置段落样式
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            paragraphStyle.paragraphSpacing = 12
            paragraphStyle.alignment = .justified
            paragraphStyle.lineBreakMode = .byWordWrapping
            
            // 为第一页调整文本区域高度
            func getTextRect(isFirstPage: Bool) -> CGRect {
                let yOffset = headerHeight + topPadding + (isFirstPage ? chapterTitleHeight : 0)
                let height = screenSize.height - yOffset - footerHeight - bottomPadding
                
                return CGRect(
                    x: horizontalPadding,
                    y: yOffset,
                    width: screenSize.width - (horizontalPadding * 2),
                    height: height
                )
            }
            
            let attributedString = NSAttributedString(
                string: content,
                attributes: [
                    .font: UIFont(name: fontFamily, size: fontSize) ?? .systemFont(ofSize: fontSize),
                    .foregroundColor: UIColor(textColor),
                    .paragraphStyle: paragraphStyle
                ]
            )
            
            let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
            var currentRange = CFRange(location: 0, length: 0)
            var pages: [String] = []
            var isFirstPage = true
            
            while currentRange.location < attributedString.length {
                // 根据是否是第一页获取不同的文本区域
                let textRect = getTextRect(isFirstPage: isFirstPage)
                let path = CGPath(rect: textRect, transform: nil)
                let frame = CTFramesetterCreateFrame(
                    frameSetter,
                    currentRange,
                    path,
                    nil
                )
                
                let frameRange = CTFrameGetVisibleStringRange(frame)
                
                // 优化分页位置
                var adjustedLength = frameRange.length
                if frameRange.length > 0 && currentRange.location + frameRange.length < attributedString.length {
                    let nsRange = NSRange(location: currentRange.location, length: frameRange.length)
                    let pageText = attributedString.attributedSubstring(from: nsRange).string
                    
                    // 只在页面内容超过一定长度时才考虑在段落边界分页
                    if pageText.count > 500 {
                        if let lastParagraphRange = pageText.range(of: "\n\n", options: .backwards) {
                            let distance = pageText.distance(from: pageText.startIndex, to: lastParagraphRange.lowerBound)
                            if distance > pageText.count / 2 {
                                adjustedLength = distance
                            }
                        }
                    }
                }
                
                if let pageContent = attributedString.attributedSubstring(
                    from: NSRange(
                        location: currentRange.location,
                        length: adjustedLength
                    )
                ).string as String? {
                    pages.append(pageContent)
                }
                
                currentRange.location += adjustedLength
                isFirstPage = false  // 第一页处理完后，设置为false
                
                if frameRange.length == 0 {
                    break
                }
            }
            
            self.pages = pages
            self.totalPages = pages.count
        }
        
        func nextPage() {
            print("nextPage called. Current page: \(currentPage), Total pages: \(totalPages), Chapter: \(chapterIndex)")
            if currentPage < totalPages - 1 {
                currentPage += 1
                saveReadingProgress()
                print("Moved to next page. New page: \(currentPage)")
            } else if chapterIndex < book.chapters.count - 1 && !isLoadingNextChapter {
                print("At last page of chapter. Loading next chapter.")
                loadNextChapter()
            } else {
                print("Already at the last page of the last chapter or loading in progress.")
            }
        }

        private func loadNextChapter() {
            guard chapterIndex < book.chapters.count - 1 && !isLoadingNextChapter else {
                print("Cannot load next chapter. Current chapter: \(chapterIndex), isLoadingNextChapter: \(isLoadingNextChapter)")
                return
            }
            
            print("Loading next chapter. Current chapter: \(chapterIndex)")
            isChapterTransitioning = true
            isChapterLoading = true
            isLoadingNextChapter = true
            chapterIndex += 1
            
            Task {
                await loadChapterContent()
                await MainActor.run {
                    print("Next chapter loaded. New chapter: \(chapterIndex), Total pages: \(totalPages)")
                    self.currentPage = 0
                    self.isChapterLoading = false
                    self.updateProgressFromCurrentPage()
                    self.saveReadingProgress()
                    self.isChapterTransitioning = false
                    self.isLoadingNextChapter = false
                    print("Set to first page of next chapter. Current page: \(self.currentPage)")
                }
            }
        }
        
        func previousPage() {
            print("previousPage called. Current page: \(currentPage), Chapter: \(chapterIndex)")
            if currentPage > 0 {
                currentPage -= 1
                saveReadingProgress()
                print("Moved to previous page. New page: \(currentPage)")
            } else if chapterIndex > 0 && !isLoadingPreviousChapter {
                print("At first page of chapter. Loading previous chapter.")
                loadPreviousChapter()
            } else {
                print("Already at the first page of the first chapter or loading in progress.")
            }
        }

        private func loadPreviousChapter() {
            guard chapterIndex > 0 && !isLoadingPreviousChapter else {
                print("Cannot load previous chapter. Current chapter: \(chapterIndex), isLoadingPreviousChapter: \(isLoadingPreviousChapter)")
                return
            }
            
            print("Loading previous chapter. Current chapter: \(chapterIndex)")
            isChapterTransitioning = true
            isChapterLoading = true
            isLoadingPreviousChapter = true
            chapterIndex -= 1
            
            Task {
                await loadChapterContent()
                await MainActor.run {
                    print("Previous chapter loaded. New chapter: \(chapterIndex), Total pages: \(totalPages)")
                    self.currentPage = self.totalPages - 1
                    self.isChapterLoading = false
                    self.updateProgressFromCurrentPage()
                    self.saveReadingProgress()
                    self.isChapterTransitioning = false
                    self.isLoadingPreviousChapter = false
                    print("Set to last page of previous chapter. Current page: \(self.currentPage)")
                }
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
        
        func updateCurrentPageFromProgress(_ progress: Double) {
            if totalPages > 1 {
                let newPage = Int(round(progress * Double(totalPages - 1)))
                if newPage != currentPage {
                    currentPage = newPage
                    objectWillChange.send()
                }
            } else {
                currentPage = 0
            }
        }
        
        func updateProgressFromCurrentPage() {
            if totalPages > 1 {
                chapterProgress = Double(currentPage) / Double(totalPages - 1)
            } else {
                chapterProgress = 0
            }
            objectWillChange.send()
        }
        
        var pageTurningModeDisplayName: String {
            displayName(for: pageTurningMode)
        }
        
        static let allPageTurningModes: [PageTurningMode] = [.curl, .horizontal, .direct]
        
        func displayName(for mode: PageTurningMode) -> String {
            switch mode {
            case .curl:
                return "仿真"
            case .horizontal:
                return "水平滑动"
            case .direct:
                return "直接切换"
            }
        }

        func setFontSize(_ newSize: CGFloat) {
            fontSize = max(16, min(30, newSize))
            Task {
                await splitContentIntoPages(currentChapterContent)
            }
        }

        // 新增方法：保存阅读进度
        func saveReadingProgress() {
            let progress = [
                "chapterIndex": chapterIndex,
                "currentPage": currentPage
            ]
            userDefaults.set(progress, forKey: "readingProgress_\(book.id)")
        }
        
        // 新增法：加载阅读进度
        private func loadReadingProgress() {
            if let progress = userDefaults.dictionary(forKey: "readingProgress_\(book.id)") {
                chapterIndex = progress["chapterIndex"] as? Int ?? 0
                currentPage = progress["currentPage"] as? Int ?? 0
            }
        }
        
        func toggleDayNightMode() {
            isDarkMode.toggle()
        }
        
        private func updateColorScheme() {
            if isDarkMode {
                backgroundColor = Color(UIColor.systemBackground)
                menuBackgroundColor = Color(UIColor.systemGray6)
                textColor = .white
            } else {
                backgroundColor = .white
                menuBackgroundColor = Color(UIColor.systemGray6)
                textColor = .black
            }
            objectWillChange.send()
        }

        func recordReadingHistory() {
            let lastChapter = book.chapters[chapterIndex].title
            let record = ReadingRecord(
                id: UUID(),
                book: book,
                lastChapter: lastChapter,
                lastReadTime: DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
            )
            
            // 获取有的阅读历史
            var readingHistory = UserDefaults.standard.readingHistory()
            
            // 除所有该书的历史记录
            readingHistory.removeAll { $0.book.id == book.id }
            
            // 添加记录到列表开头
            readingHistory.insert(record, at: 0)
            
            // 限历史记录数量
            if readingHistory.count > 20 {
                readingHistory = Array(readingHistory.suffix(20))
            }
            
            // 保存更新阅读历史
            UserDefaults.standard.saveReadingHistory(readingHistory)
        }
        
        // 预加后续章节
        private func preloadNextChapters() {
            guard autoPreload else { return }
            
            Task {
                for offset in 1...preloadChapterCount {
                    let nextChapterIndex = chapterIndex + offset
                    guard nextChapterIndex < book.chapters.count else { break }
                    
                    // 如果该章节已经预加载，则跳过
                    guard preloadedChapters[nextChapterIndex] == nil else { continue }
                    
                    do {
                        let chapterURL = book.chapters[nextChapterIndex].link
                        let content = try await fetchChapterContent(from: chapterURL)
                        await MainActor.run {
                            preloadedChapters[nextChapterIndex] = content
                            print("预加载完成：第 \(nextChapterIndex + 1) 章")
                        }
                    } catch {
                        print("预加载失败：第 \(nextChapterIndex + 1) 章 - \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // 清理预加载缓存的方法
        func clearPreloadCache() {
            preloadedChapters.removeAll()
        }

        // 修改字体时重新分页
        func setFont(_ newFont: String) {
            fontFamily = newFont
            Task {
                await splitContentIntoPages(currentChapterContent)
            }
        }
    }
