import SwiftUI
import SwiftSoup

class BookReadingViewModel: ObservableObject {
        @Published var isSystemInDarkMode: Bool = false {
            didSet {
                updateColorSchemeBasedOnSystem()
            }
        }
        @Published var book: Book
        @Published var currentPage: Int = 0
        @Published var totalPages: Int = 1
        @Published var pages: [String] = []
        @Published var chapterIndex: Int = 0
        @Published var showSettings: Bool = false
        @Published var showChapterList: Bool = false
        @Published var showFontSettings: Bool = false
        @Published var isChapterListReversed: Bool = false
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
        private let shouldSaveProgress: Bool
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
        init(book: Book, 
             startingChapter: Int, 
             startingPage: Int, 
             initialFontSize: CGFloat,
             shouldSaveProgress: Bool,
             isDayMode: Bool,
             savedColorIndex: Int) {
            
            // 首先初始化所有存储属性
            self.book = book
            self.chapterIndex = startingChapter
            self.startingPage = startingPage
            self.currentPage = startingPage
            self.fontSize = initialFontSize
            self.shouldSaveProgress = shouldSaveProgress
            self.isSystemInDarkMode = !isDayMode
            self.currentChapterContent = ""
            self.pages = []
            self.totalPages = 1
            self.showSettings = false
            self.showChapterList = false
            self.showFontSettings = false
            self.isChapterListReversed = false
            self.fontFamily = "PingFang SC"  // 设置默认字体
            self.dragOffset = 0
            self.isLoading = false
            self.errorMessage = nil
            self.chapterProgress = 0
            self.isChapterLoading = false
            self.nextChapterTitle = ""
            self.isChapterTransitioning = false
            self.isLoadingPreviousChapter = false
            self.isLoadingNextChapter = false
            self.initialLoad = true
            self.pageTurningMode = .curl
            self.brightness = Double(UIScreen.main.brightness)
            
            // 初始化 currentFont
            self.currentFont = FontOption(name: "苹方", fontName: "PingFang SC")
            
            // 根据系统模式设置背景色
            if isDayMode {
                // 白天模式：使用保存的背景色
                self.backgroundColor = backgroundColors[savedColorIndex]
                self.textColor = UIColor(backgroundColors[savedColorIndex]).brightness < 0.5 ? .white : .black
            } else {
                // 暗黑模式：强制使用黑色背景
                self.backgroundColor = .black
                self.textColor = .white
            }
            
            // 设置菜单背景色
            self.menuBackgroundColor = Color(UIColor.systemGray6)
        }
        
        func initializeBook(progressCallback: @escaping (Double) -> Void) {
            print("开始初始化书籍: \(book.title)")
            Task {
                await loadAllChapters(progressUpdate: progressCallback)
                
                // 加载用户选择的章节
                await MainActor.run {
                    // 如果不需要保存进度，总是从第一页开始
                    if !shouldSaveProgress {
                        currentPage = 0
                    }
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
            print("\n=== 开始加载书章节 ===")
            print("书籍标题: \(book.title)")
            print("书籍链接: \(book.link)\n")
            
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
                print("找到总章节数: \(totalChapters)\n")
                print("=== 前20章节信息 ===")
                
                let newChapters = try chapterElements.enumerated().compactMap { index, element -> Book.Chapter? in
                    let title = try element.text()
                    let relativeLink = try element.attr("href")
                    
                    // Filter out the "展开全部章节" chapter
                    guard !title.contains("展开全部章") else {
                        print("跳过展开全部章节链接")
                        return nil
                    }
                    
                    // 构建正确的完整链接，移除多余的 /books/
                    let fullLink = "https://www.bqgda.cc" + relativeLink
                    
                    // 打印前20章的信息
                    if index < 20 {
                        print("\(index + 1). \(title)")
                        print("   链接: \(fullLink)\n")
                    }
                    
                    // Update progress
                    DispatchQueue.main.async {
                        progressUpdate(Double(index + 1) / Double(totalChapters))
                    }
                    
                    return Book.Chapter(title: title, link: fullLink)
                }
                
                // 打印章节汇总信息
                if let firstChapter = newChapters.first,
                   let lastChapter = newChapters.last {
                    print("\n=== 章节信息汇总 ===")
                    print("第一章:")
                    print("  标题: \(firstChapter.title)")
                    print("  链接: \(firstChapter.link)")
                    print("\n最后一章:")
                    print("  标题: \(lastChapter.title)")
                    print("  链接: \(lastChapter.link)")
                    print("\n有效章节总数: \(newChapters.count)")
                    print("===================\n")
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
                print("加载章节失败: \(error.localizedDescription)")
            }
        }
        
        func loadChapter(at index: Int, resetPage: Bool = true, goToLastPage: Bool = false) {
            print("加载章节. 索引: \(index), 重置页码: \(resetPage), 初始加载: \(initialLoad), 跳转到最后一页: \(goToLastPage)")
            guard index >= 0 && index < book.chapters.count else { return }
            
            isChapterLoading = true
            chapterIndex = index
            
            if let preloadedContent = preloadedChapters[index] {
                Task { @MainActor in
                    currentChapterContent = preloadedContent
                    splitContentIntoPages(preloadedContent)
                    isChapterLoading = false
                    if resetPage {
                        if shouldSaveProgress && initialLoad && index == chapterIndex {
                            currentPage = startingPage
                            initialLoad = false
                            print("使用保存的页码: \(startingPage)")
                        } else if goToLastPage {
                            currentPage = max(0, totalPages - 1)
                            print("跳转到最后一页: \(currentPage)")
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
                            if shouldSaveProgress && initialLoad {
                                self.currentPage = startingPage
                                initialLoad = false
                                print("使用保存的页码: \(startingPage)")
                            } else if goToLastPage {
                                self.currentPage = max(0, self.totalPages - 1)
                                print("跳转到最后一页: \(self.currentPage)")
                            } else {
                                self.currentPage = 0
                            }
                        }
                        self.updateProgressFromCurrentPage()
                        self.isChapterLoading = false
                    }
                    // 加载完成后触发预加载
                    preloadChapters()
                }
            }
        }
        
        // 新增方法：从章节列表加载章节
        func loadChapterFromList(at index: Int) {
            // 从目录加载时总是重置页码到第一页
            loadChapter(at: index, resetPage: true)
            // 如果不需要保存进度，确保当前页为0
            if !shouldSaveProgress {
                currentPage = 0
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
            
            // 获取HTML内容进行处理
            var processedContent = try contentElement?.html() ?? ""
            
            // 移除开头的新推荐部分
            if let range = processedContent.range(of: "新推荐") {
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
            
            // 将内容按行分割
            var lines = processedContent.components(separatedBy: .newlines)
            
            // 移除所有与章节标题相关的行
            lines.removeAll { line in
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 完全匹配
                if trimmedLine == chapterTitle {
                    return true
                }
                
                // 匹配包含章节序号和标题的组合
                if trimmedLine.contains(chapterTitle) || 
                   trimmedLine.contains("第") && trimmedLine.contains("��") {
                    return true
                }
                
                return false
            }
            
            // 新组合内容，确保段落之间有适当的间距
            let paragraphs = lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { "　　\($0)" }
            
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
            
            // 规范化空白字符，但留段落格式
            cleanedContent = cleanedContent
                .replacingOccurrences(of: " +", with: " ", options: .regularExpression)  // 合并多个空格
                .replacingOccurrences(of: "\n\\s+", with: "\n", options: .regularExpression)  // 清理首空白
                .replacingOccurrences(of: "\\s+\n", with: "\n", options: .regularExpression)  // 清理行尾白
                .replacingOccurrences(of: "\n{4,}", with: "\n\n\n", options: .regularExpression)  // 最多保留三个连续换行
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return cleanedContent
        }
        
        @MainActor
        func splitContentIntoPages(_ content: String) {
            let screenSize = UIScreen.main.bounds.size
            let headerHeight: CGFloat = 40  // 导航栏高度
            let footerHeight: CGFloat = 25  // 减小底部高度
            let horizontalPadding: CGFloat = 20
            let bottomPadding: CGFloat = 15  // 减小底部内边距
            
            // 配置段落样式和字体
            let paragraphStyle = NSMutableParagraphStyle()
            let font = UIFont(name: fontFamily, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
            let titleFont = UIFont(name: fontFamily, size: fontSize * 1.4)?.withTraits(.traitBold) ?? 
                           UIFont.boldSystemFont(ofSize: fontSize * 1.4)
            
            // 计算行高和间距
            let lineHeight = font.lineHeight
            let titleLineHeight = titleFont.lineHeight
            let lineSpacing: CGFloat = lineHeight * 0.2  // 减小行距到20%
            
            // 获取章节标题并动态计算所需度
            let chapterTitle = book.chapters[chapterIndex].title
            let titleSize = (chapterTitle as NSString).boundingRect(
                with: CGSize(
                    width: screenSize.width - (horizontalPadding * 2),
                    height: .greatestFiniteMagnitude
                ),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: titleFont],
                context: nil
            )
            
            // 计算标题实际占用的高度（包括可能的换行）
            let titleHeight = ceil(titleSize.height)
            // 在标题上下添加一些额外的间距
            let titleTopMargin: CGFloat = 16
            let titleBottomMargin: CGFloat = 24
            let totalTitleHeight = titleHeight + titleTopMargin + titleBottomMargin
            
            // 更新 getTextRect 函数
            func getTextRect(isFirstPage: Bool) -> CGRect {
                let topPadding: CGFloat = isFirstPage ? totalTitleHeight : 10
                let height = screenSize.height - headerHeight - footerHeight - topPadding - bottomPadding
                
                return CGRect(
                    x: horizontalPadding,
                    y: headerHeight + topPadding,
                    width: screenSize.width - (horizontalPadding * 2),
                    height: height
                )
            }
            
            // 设置段落样式
            paragraphStyle.lineSpacing = lineSpacing
            paragraphStyle.paragraphSpacing = lineSpacing  // 段落间距与行间距相同
            paragraphStyle.alignment = .justified
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.minimumLineHeight = lineHeight
            paragraphStyle.maximumLineHeight = lineHeight
            
            // 预处理文本，移除所有章节标题相关的内容
            var cleanedContent = content
            
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
                    .replacingOccurrences(of: "��", with: "")
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
            
            // 添加正文不再添加标题
            let contentAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(textColor),
                .paragraphStyle: paragraphStyle
            ]
            let contentAttributedString = NSAttributedString(string: cleanedContent, attributes: contentAttributes)
            attributedString.append(contentAttributedString)
            
            let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
            var currentRange = CFRange(location: 0, length: 0)
            var pages: [String] = []
            var isFirstPage = true
            
            while currentRange.location < attributedString.length {
                let textRect = getTextRect(isFirstPage: isFirstPage)
                // 创建一个稍小的渲区域，但只预留很小的安全边距
                let adjustedRect = CGRect(
                    x: textRect.origin.x,
                    y: textRect.origin.y,
                    width: textRect.width,
                    height: textRect.height - (lineHeight * 0.5)  // 只预留半个行高的空间
                )
                let path = CGPath(rect: adjustedRect, transform: nil)
                
                // 获取建议的页面大小
                let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
                    frameSetter,
                    currentRange,
                    nil,
                    CGSize(width: textRect.width, height: textRect.height),
                    nil
                )
                
                // 创建frame并获取实际可见范围
                let frame = CTFramesetterCreateFrame(
                    frameSetter,
                    currentRange,
                    path,
                    nil
                )
                
                let frameRange = CTFrameGetVisibleStringRange(frame)
                var adjustedLength = frameRange.length
                
                // 检查最后一行是否完整
                let lines = CTFrameGetLines(frame) as! [CTLine]
                if let lastLine = lines.last {
                    let lineRange = CTLineGetStringRange(lastLine)
                    let lineEnd = lineRange.location + lineRange.length
                    
                    // 如果最后一行不整，减少页面内容直接上一行
                    if lineEnd > frameRange.location + frameRange.length {
                        // 找到上一行的结束位置
                        if lines.count > 1 {
                            let previousLine = lines[lines.count - 2]
                            let previousLineRange = CTLineGetStringRange(previousLine)
                            adjustedLength = (previousLineRange.location + previousLineRange.length) - frameRange.location
                        }
                    }
                }
                
                let length = max(adjustedLength, 1)
                
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
            
            // 只保留必要的日志
            print("\n===== 章节分页信息 =====")
            print("总页数: \(pages.count)")
            print("字体: \(fontFamily), 大小: \(fontSize)")
        }
        
        func nextPage() {
            if currentPage < totalPages - 1 {
                currentPage += 1
                updateProgressFromCurrentPage()
            } else {
                // 当前章节已读完，尝试加载下一章
                var nextIndex = chapterIndex + 1
                while nextIndex < book.chapters.count && !isValidChapter(nextIndex) {
                    nextIndex += 1
                }
                
                if nextIndex < book.chapters.count {
                    loadChapter(at: nextIndex)
                }
            }
        }

        private func loadNextChapter() {
            guard chapterIndex < book.chapters.count - 1 && !isLoadingNextChapter else {
                return
            }
            
            isChapterTransitioning = true
            isChapterLoading = true
            isLoadingNextChapter = true
            chapterIndex += 1
            
            Task {
                await loadChapterContent()
                await MainActor.run {
                    self.currentPage = 0
                    self.isChapterLoading = false
                    self.updateProgressFromCurrentPage()
                    self.isChapterTransitioning = false
                    self.isLoadingNextChapter = false
                }
            }
        }
        
        func previousPage() {
            if currentPage > 0 {
                currentPage -= 1
                updateProgressFromCurrentPage()
            } else {
                // 当前章节已到开头，尝试加载上一章
                var prevIndex = chapterIndex - 1
                while prevIndex >= 0 && !isValidChapter(prevIndex) {
                    prevIndex -= 1
                }
                
                if prevIndex >= 0 {
                    loadChapter(at: prevIndex, goToLastPage: true)
                }
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
                    self.isChapterTransitioning = false
                    self.isLoadingPreviousChapter = false
                    print("Set to last page of previous chapter. Current page: \(self.currentPage)")
                }
            }
        }
        
        func nextChapter() {
            var nextIndex = chapterIndex + 1
            // 跳过无效章节
            while nextIndex < book.chapters.count && !isValidChapter(nextIndex) {
                nextIndex += 1
            }
            
            if nextIndex < book.chapters.count {
                loadChapter(at: nextIndex)
            }
        }
        
        func previousChapter() {
            var prevIndex = chapterIndex - 1
            // 跳过无效章节
            while prevIndex >= 0 && !isValidChapter(prevIndex) {
                prevIndex -= 1
            }
            
            if prevIndex >= 0 {
                loadChapter(at: prevIndex)
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
            saveProgress()
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

        // 增方法：保存阅读进度
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
            isSystemInDarkMode.toggle()
        }
        
        func recordReadingHistory() {
            let lastChapter = book.chapters[chapterIndex].title
            let record = ReadingRecord(
                id: UUID(),
                book: book,
                lastChapter: lastChapter,
                lastReadTime: DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
            )
            
            // 获取有的阅读历
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
                    
                    // 检查章节索引是���有效
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
        
        // 修改字体时重��分页
        func setFont(_ newFont: String) {
            fontFamily = newFont
            Task {
                await splitContentIntoPages(currentChapterContent)
            }
        }

        func retryLoadCurrentChapter() {
            print("\n===== 重试加载章节 =====")
            print("章节索引: \(chapterIndex)")
            
            // 清除错误消息
            errorMessage = nil
            
            // 重置加载状态
            isChapterLoading = true
            
            // 重新加载当前章节
            Task {
                do {
                    if let chapter = book.chapters[safe: chapterIndex] {
                        print("重试加载章节: \(chapter.title)")
                        print("章节链接: \(chapter.link)")
                        
                        // 修改这里：直接使用 fetchChapterContent 而不是 loadChapterContent
                        let content = try await fetchChapterContent(from: chapter.link)
                        await MainActor.run {
                            currentChapterContent = content
                            splitContentIntoPages(content)
                            isChapterLoading = false
                        }
                    } else {
                        await MainActor.run {
                            errorMessage = "无效的章节索引"
                            isChapterLoading = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "重试加载失败: \(error.localizedDescription)"
                        isChapterLoading = false
                    }
                }
            }
        }

        func saveProgress() {
            guard shouldSaveProgress else { return }
            
            let progress: [String: Any] = [
                "chapterIndex": chapterIndex,
                "currentPage": currentPage
            ]
            UserDefaults.standard.set(progress, forKey: "readingProgress_\(book.id)")
        }

        // 添加新的方法来根据系统设置更新配色
        private func updateColorSchemeBasedOnSystem() {
            if isSystemInDarkMode {
                backgroundColor = .black
                textColor = .white
            } else {
                // 使用保存的背景色或默认白色
                let savedColorIndex = UserDefaultsManager.shared.getSelectedBackgroundColorIndex()
                backgroundColor = backgroundColors[safe: savedColorIndex] ?? .white
                textColor = UIColor(backgroundColor).brightness < 0.5 ? .white : .black
            }
            objectWillChange.send()
        }

        // 在 BookReadingViewModel 中添加一个辅助方法来判断有效章节
        private func isValidChapter(_ index: Int) -> Bool {
            guard index >= 0 && index < book.chapters.count else { return false }
            return !book.chapters[index].title.contains("---展开全部章节---")
        }
    }

// 添加安全索引访问扩
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
