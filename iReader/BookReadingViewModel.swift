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
        @Published var backgroundColors: [Color] = [
            .white,
            Color(red: 0.95, green: 0.95, blue: 0.87), // 米色
            Color(red: 0.86, green: 0.93, blue: 0.87), // 浅绿
            .black
        ]
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
        
        @AppStorage("autoPreload") private var autoPreload = true
        @AppStorage("preloadChaptersCount") private var preloadChaptersCount = 5
        
        // 预加载缓存
        private var preloadedChapters: [Int: String] = [:]
        private let preloadQueue = DispatchQueue(label: "com.iReader.preload", qos: .background)
        private var isPreloading = false
        
        // 预加载章节
        private func preloadChapters() {
            guard autoPreload else { return }
            
            let currentIndex = chapterIndex
            let totalChapters = book.chapters.count
            
            // 清理不需要的缓存
            preloadedChapters = preloadedChapters.filter { index, _ in
                index > currentIndex && index <= currentIndex + preloadChaptersCount
            }
            
            // 预加载后续章节
            for i in 1...preloadChaptersCount {
                let targetIndex = currentIndex + i
                if targetIndex < totalChapters && preloadedChapters[targetIndex] == nil {
                    Task {
                        let chapterURL = book.chapters[targetIndex].link
                        if let content = try? await fetchChapterContent(from: chapterURL) {
                            DispatchQueue.main.async {
                                self.preloadedChapters[targetIndex] = content
                                print("预加载完成第 \(targetIndex) 章")
                            }
                        }
                    }
                }
            }
        }
        
        // 修改加载章节的方法
        private func loadChapterContent() async {
            do {
                guard chapterIndex < book.chapters.count else {
                    throw NSError(domain: "ChapterError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid chapter index"])
                }
                
                // 检查是否有预加载的内容
                if let preloadedContent = preloadedChapters[chapterIndex] {
                    await MainActor.run {
                        self.currentChapterContent = preloadedContent
                        self.splitContentIntoPages(preloadedContent)
                        print("使用预加载内容：第 \(chapterIndex) 章")
                    }
                    // 清理已使用的预加载内容
                    preloadedChapters.removeValue(forKey: chapterIndex)
                } else {
                    let chapterURL = book.chapters[chapterIndex].link
                    let content = try await fetchChapterContent(from: chapterURL)
                    
                    await MainActor.run {
                        self.currentChapterContent = content
                        self.splitContentIntoPages(content)
                        self.isLoading = false
                    }
                }
                
                // 触发预加载下一批章节
                preloadChapters()
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
        
        // 清理预加载缓存
        func clearPreloadCache() {
            preloadedChapters.removeAll()
        }
        
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
        
        // 修改字体属为 FontOption
        @Published var currentFont: FontOption {
            didSet {
                fontFamily = currentFont.fontName
                // 保存字体系列设置
                UserDefaultsManager.shared.saveFontFamily(currentFont.fontName)
            }
        }
        
        // 添加起始页属性
        private var startingPage: Int
        
        // 修改初始化方法
        init(book: Book, startingChapter: Int = 0, startingPage: Int = 0, initialFontSize: CGFloat = 20) {
            print("初始化 ViewModel - 书籍: \(book.title), 起始章节: \(startingChapter), 起始页码: \(startingPage), 初始字体大小: \(initialFontSize)")
            self.book = book
            self.chapterIndex = startingChapter
            self.startingPage = startingPage
            self.fontSize = initialFontSize
            
            // 设置默认字体为细黑体（假设它是第三个字体）
            if availableFonts.count >= 3 {
                self.currentFont = availableFonts[2]
                self.fontFamily = availableFonts[2].fontName
            }
            
            // 从 UserDefaults 加载保存的字体系列
            let savedFontFamily = UserDefaultsManager.shared.getFontFamily()
            // 查找匹配的字体选项
            let matchedFont = availableFonts.first { $0.fontName == savedFontFamily } ?? 
                             FontOption(name: "苹方", fontName: "PingFang SC")
            
            self.currentFont = matchedFont
            self.fontFamily = matchedFont.fontName
            
            // 加载保存的背景颜色选择
            let savedColorIndex = UserDefaultsManager.shared.getSelectedBackgroundColorIndex()
            self.backgroundColor = backgroundColors[safe: savedColorIndex] ?? .white
            self.textColor = backgroundColor == .black ? .white : .black
        }
        
        func initializeBook(progressCallback: @escaping (Double) -> Void) {
            print("开始初始化书籍: \(book.title)")
            Task {
                await loadAllChapters(progressUpdate: progressCallback)
                
                // 接加载用户选择的章节
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
            print("加载章节. 索引: \(index), 重置页码: \(resetPage), 初始加载: \(initialLoad)")
            guard index >= 0 && index < book.chapters.count else { return }
            
            isChapterLoading = true
            chapterIndex = index
            
            if let preloadedContent = preloadedChapters[index] {
                Task { @MainActor in
                    currentChapterContent = preloadedContent
                    splitContentIntoPages(preloadedContent)
                    isChapterLoading = false
                    if resetPage {
                        if initialLoad && index == chapterIndex {
                            currentPage = startingPage
                            initialLoad = false
                            print("使用保存的页码: \(startingPage)")
                        } else {
                            currentPage = 0
                        }
                    }
                    // 清理已使用的预加载内容
                    preloadedChapters.removeValue(forKey: index)
                    // 触发新的预加载
                    preloadChapters()
                }
            } else {
                Task {
                    await loadChapterContent()
                    await MainActor.run {
                        self.isChapterLoading = false
                        if resetPage {
                            if initialLoad {
                                self.currentPage = startingPage
                                initialLoad = false
                                print("使用保存的页码: \(startingPage)")
                            } else {
                                self.currentPage = 0
                            }
                        }
                        self.updateProgressFromCurrentPage()
                        self.saveReadingProgress()
                        print("正常加载完成： \(index + 1) 章，页码：\(self.currentPage)")
                    }
                    // 加载完成后触发预加载
                    preloadChapters()
                }
            }
        }
        
        // 新增方法：从章节列表加载章节
        func loadChapterFromList(at index: Int) {
            loadChapter(at: index, resetPage: true)
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
            
            // 移除开头的新书推荐部分
            if let range = processedContent.range(of: "新书推荐：") {
                if let endRange = processedContent[range.upperBound...].range(of: "\n\n") {
                    processedContent = String(processedContent[endRange.upperBound...])
                }
            }
            
            // 移除结尾的请收藏本站内容
            if let range = processedContent.range(of: "请收藏本站") {
                if let startRange = processedContent[..<range.lowerBound].lastIndex(of: "\n") {
                    processedContent = String(processedContent[..<startRange])
                }
            }
            
            // 清理HTML并格式化段落
            processedContent = cleanHTML(processedContent)
            
            // 获取当前章节标题
            let chapterTitle = book.chapters[chapterIndex].title
            
            // 去除章节标题
            
            // 将内容按行分割并处理
            var lines = processedContent.components(separatedBy: .newlines)
            
            // 移除所有与章节标题相关的行
            lines.removeAll { line in
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 如果行包含完整的章节标题，则移除
                if trimmedLine.contains(chapterTitle) {
                    return true
                }
                
                // 如果行就是章节标题（忽略空格和大小写），则移除
                if trimmedLine.lowercased().replacingOccurrences(of: " ", with: "") == 
                   chapterTitle.lowercased().replacingOccurrences(of: " ", with: "") {
                    return true
                }
                
                return false
            }
            
            // 过滤和格式化剩余的段落
            let paragraphs = lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { paragraph in 
                    !paragraph.isEmpty &&
                    !paragraph.contains("新书推荐") &&
                    !paragraph.contains("笔趣阁") &&
                    !paragraph.contains("请收藏") &&
                    paragraph.count >= 2
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
                .replacingOccurrences(of: "\n\\s+", with: "\n", options: .regularExpression)  // 清理首空白
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
            let chapterTitleHeight: CGFloat = 60
            
            // 配置段落样式和字体
            let paragraphStyle = NSMutableParagraphStyle()
            let font = UIFont(name: fontFamily, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
            let titleFont = UIFont(name: fontFamily, size: fontSize * 1.2) ?? UIFont.systemFont(ofSize: fontSize * 1.2)
            
            // 计算行高和间距
            let lineHeight = font.lineHeight
            let lineSpacing: CGFloat = lineHeight * 0.2 // 保持20%的行间距
            
            paragraphStyle.lineSpacing = lineSpacing
            paragraphStyle.paragraphSpacing = 0
            paragraphStyle.alignment = .justified
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.minimumLineHeight = lineHeight
            paragraphStyle.maximumLineHeight = lineHeight
            
            // 计算可用区域，考虑第一页的标题
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
            
            // 预处理文本，移除所有章节标题相关的内容
            var cleanedContent = content
            let chapterTitle = book.chapters[chapterIndex].title
            
            // 将内容按行分割
            var lines = cleanedContent.components(separatedBy: .newlines)
            
            // 移除所有包含章节标题的行
            lines.removeAll { line in
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 完全匹配
                if trimmedLine == chapterTitle {
                    return true
                }
                
                // 匹配包含章节序号和标题的组合
                let cleanTitle = chapterTitle
                    .replacingOccurrences(of: "第", with: "")
                    .replacingOccurrences(of: "章", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    
                if trimmedLine.contains(cleanTitle) {
                    return true
                }
                
                return false
            }
            
            // 重新组合内容
            cleanedContent = lines.joined(separator: "\n")
            
            // 创建复合属性字符串
            let attributedString = NSMutableAttributedString()
            
            // 只在第一页顶部添加标题
            let titleText = book.chapters[chapterIndex].title + "\n\n"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: fontFamily, size: fontSize * 1.4)?.withTraits(.traitBold) ?? 
                      UIFont.boldSystemFont(ofSize: fontSize * 1.4),
                .foregroundColor: UIColor(textColor),
                .paragraphStyle: paragraphStyle
            ]
            let titleAttributedString = NSAttributedString(string: titleText, attributes: titleAttributes)
            attributedString.append(titleAttributedString)
            
            // 添加正文（使用清理过的内容）
            let contentAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(textColor),
                .paragraphStyle: paragraphStyle,
                .baselineOffset: 0,
                .kern: 0
            ]
            let contentAttributedString = NSAttributedString(string: cleanedContent, attributes: contentAttributes)
            attributedString.append(contentAttributedString)
            
            let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
            var currentRange = CFRange(location: 0, length: 0)
            var pages: [String] = []
            var isFirstPage = true
            
            while currentRange.location < attributedString.length {
                let textRect = getTextRect(isFirstPage: isFirstPage)
                let path = CGPath(rect: textRect, transform: nil)
                
                // 创建frame并获取实际可见范围
                let frame = CTFramesetterCreateFrame(
                    frameSetter,
                    currentRange,
                    path,
                    nil
                )
                
                let frameRange = CTFrameGetVisibleStringRange(frame)
                let length = max(frameRange.length, 1)
                
                if let pageContent = attributedString.attributedSubstring(
                    from: NSRange(
                        location: currentRange.location,
                        length: length
                    )
                ).string as String? {
                    pages.append(pageContent)
                }
                
                currentRange.location += length
                isFirstPage = false
                
                if frameRange.length == 0 {
                    break
                }
            }
            
            self.pages = pages
            self.totalPages = pages.count
            
            print("分页完成 - 总页数: \(pages.count)")
            print("使用字体: \(fontFamily), 大小: \(fontSize)")
            print("标题字体大小: \(fontSize * 1.2)")
            print("行高: \(lineHeight), 行间距: \(lineSpacing)")
            print("首页可用高度: \(getTextRect(isFirstPage: true).height)")
            print("后续页面可用高度: \(getTextRect(isFirstPage: false).height)")
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
                "currentPage": currentPage,
                "lastReadTime": Date().timeIntervalSince1970
            ] as [String : Any]
            
            userDefaults.set(progress, forKey: "readingProgress_\(book.id)")
        }
        
        // 新增法：加阅读进度
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
            // 防止重复预加载
            guard !isPreloading else { return }
            isPreloading = true
            
            preloadQueue.async { [weak self] in
                guard let self = self else { return }
                
                // 获取需要预加载的章节索引
                let currentIndex = self.chapterIndex
                let chaptersCount = self.book.chapters.count
                let preloadRange = 1...2 // 预加载接下来的2章
                
                for offset in preloadRange {
                    let nextChapterIndex = currentIndex + offset
                    
                    // 检查章节索引是否有效
                    guard nextChapterIndex < chaptersCount else { continue }
                    
                    // 检查是否已经预加载
                    if self.preloadedChapters[nextChapterIndex] != nil {
                        continue
                    }
                    
                    // 异步加载章节内容
                    Task {
                        do {
                            let chapterURL = self.book.chapters[nextChapterIndex].link
                            let content = try await self.fetchChapterContent(from: chapterURL)
                            
                            await MainActor.run {
                                self.preloadedChapters[nextChapterIndex] = content
                                print("预加载完成：第 \(nextChapterIndex + 1) 章")
                            }
                        } catch {
                            print("预加载章节失败: \(error)")
                        }
                    }
                }
                
                // 清理不需要的预加载内容
                self.cleanupPreloadedChapters(currentIndex: currentIndex)
                self.isPreloading = false
            }
        }
        
        // 清理预加载的章节
        private func cleanupPreloadedChapters(currentIndex: Int) {
            let keepRange = (currentIndex - 1)...(currentIndex + 2)
            preloadedChapters = preloadedChapters.filter { keepRange.contains($0.key) }
        }
        
        // 修改获取章节内容的方法
        func getChapterContent(at index: Int) -> String? {
            return preloadedChapters[index]
        }
        
        // 修改字体时重新分页
        func setFont(_ newFont: String) {
            fontFamily = newFont
            Task {
                await splitContentIntoPages(currentChapterContent)
            }
        }
    }

// 添加安全索引访问扩展
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            // 如果无法创建带特征的字体，返回加粗的系统字体
            return UIFont.boldSystemFont(ofSize: pointSize)
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
