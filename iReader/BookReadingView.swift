import SwiftUI
import SwiftSoup

struct BookReadingView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: BookReadingViewModel
    @Binding var isPresented: Bool
    @State private var pageTurningMode: PageTurningMode = .curl
    @State private var isParsing: Bool = true
    @State private var parsingProgress: Double = 0
    @State private var showSettingsPanel: Bool = false
    @State private var showSecondLevelSettings: Bool = false
    @State private var showThirdLevelSettings: Bool = false
    @State private var tempFontSize: CGFloat = 20 // 用于临时存储字体大小
    @State private var pageResetTrigger = false // 新增：用于触发页面重置
    
    // 修改后的初始化方法，增加 `startingChapter` 参数，默认值为 0
    init(book: Book, isPresented: Binding<Bool>, startingChapter: Int = 0) {
        print("BookReadingView initialized with book: \(book.title), startingChapter: \(startingChapter)")
        _viewModel = StateObject(wrappedValue: BookReadingViewModel(book: book, startingChapter: startingChapter))
        _isPresented = isPresented
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 将背景颜色应用到最外层 ZStack
                viewModel.backgroundColor
                    .edgesIgnoringSafeArea(.all) // 确保背景颜色覆盖整个屏幕

                if isParsing {
                    parsingView
                } else if viewModel.isLoading || viewModel.isChapterLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.pages.isEmpty {
                    emptyContentView
                } else {
                    bookContent(in: geometry)
                }

                // 将侧边栏覆盖在内容之上
                chapterListView
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
        .onChange(of: viewModel.currentPage) { _ in
            viewModel.updateProgressFromCurrentPage()
        }
        .onDisappear {
            viewModel.saveReadingProgress()
            viewModel.recordReadingHistory()
        }
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
            PageTurningView(
                mode: viewModel.pageTurningMode,
                currentPage: $viewModel.currentPage,
                totalPages: viewModel.totalPages,
                onPageChange: { newPage in
                    print("onPageChange called. New page: \(newPage), Total pages: \(viewModel.totalPages)")
                    if !viewModel.isChapterTransitioning && !viewModel.isLoadingNextChapter {
                        if newPage > viewModel.totalPages - 1 {
                            print("Attempting to go to next chapter")
                            viewModel.nextPage()
                            pageResetTrigger.toggle()
                        } else if newPage < 0 {
                            print("Attempting to go to previous chapter")
                            viewModel.previousPage()
                            pageResetTrigger.toggle()
                        } else {
                            viewModel.currentPage = newPage
                            print("Page changed within chapter. New page: \(newPage)")
                        }
                    } else {
                        print("Chapter is transitioning or loading. Ignoring page change.")
                    }
                },
                onNextChapter: {
                    print("onNextChapter called")
                    if !viewModel.isLoadingNextChapter {
                        viewModel.nextPage()
                        pageResetTrigger.toggle()
                    }
                },
                onPreviousChapter: {
                    print("onPreviousChapter called")
                    viewModel.previousPage()
                    pageResetTrigger.toggle()
                },
                contentView: { index in
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Button(action: {
                                self.presentationMode.wrappedValue.dismiss()
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
                        .background(viewModel.backgroundColor)

                        // Page content
                        pageView(for: index, in: geometry)
                            .frame(maxHeight: .infinity)

                        Spacer(minLength: 0) // 添加这行，使 footer 尽可能靠近底部

                        // Footer
                        bottomToolbar
                            .frame(height: 10)
                            .background(viewModel.backgroundColor)
                            .padding(.bottom, 0) // 添加一个小的底部 padding
                    }
                    .background(viewModel.backgroundColor)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTapGesture(location: location, in: geometry)
                    }
                },
                isChapterLoading: $viewModel.isChapterLoading,
                onPageTurningGesture: {
                    if showSettingsPanel {
                        showSettingsPanel = false
                    }
                }
            )
            .id(viewModel.chapterIndex)
            .onChange(of: viewModel.chapterIndex) { newValue in
                print("Chapter index changed to: \(newValue)")
            }
            .onChange(of: viewModel.currentPage) { newValue in
                print("Current page changed to: \(newValue)")
            }
            .edgesIgnoringSafeArea(.all)

            // 设置悬浮层
            settingsOverlay(in: geometry)
        }
    }
    
    private func settingsOverlay(in geometry: GeometryProxy) -> some View {
        Group {
            if showThirdLevelSettings {
                thirdLevelSettingsPanel
            } else if showSecondLevelSettings {
                secondLevelSettingsPanel
            } else {
                settingsPanel
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)))
        .offset(y: showSettingsPanel ? 0 : geometry.size.height)
        .animation(.none)
    }
    
    private func pageView(for index: Int, in geometry: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            // 添加一个透明的背景，使得整个中间区域都能响应手势
            Color.clear
                .frame(width: geometry.size.width, height: geometry.size.height - 80)
                .contentShape(Rectangle()) // 确保整个区域可响应手势

            if index >= 0 && index < viewModel.pages.count {
                // 文字内容
                Text(viewModel.pages[index])
                    .font(.custom(viewModel.fontFamily, size: viewModel.fontSize))
                    .foregroundColor(viewModel.textColor)
                    .lineSpacing(viewModel.lineSpacing)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            } else {
                // 当没有内容时，填充空白
                EmptyView()
            }
        }
    }
    
    private var settingsPanel: some View {
        VStack(spacing: 0) {
            // 第一行：上一章、滑动条、下一章
            HStack {
                chapterButton(text: "上一章", imageName: "chevron.left") {
                    viewModel.previousChapter()
                }
                
                CustomSlider(value: $viewModel.chapterProgress, range: 0...1) { _ in
                    // 移除这里的 updateCurrentPageFromProgress 调用
                } onValueChanged: { newValue in
                    viewModel.updateCurrentPageFromProgress(newValue)
                }
                .disabled(viewModel.totalPages <= 1)
                
                chapterButton(text: "下一章", imageName: "chevron.right") {
                    viewModel.nextChapter()
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 5)
            
            Divider()
                .background(viewModel.textColor.opacity(0.2))
            
            // 第二行：目录、日/夜间模式和设置
            HStack(spacing: 0) {
                buttonView(imageName: "list.bullet", text: "目录") {
                    withAnimation {
                        viewModel.showChapterList.toggle()
                        showSettingsPanel = false
                    }
                }
                buttonView(imageName: viewModel.isDarkMode ? "sun.max.fill" : "moon.fill", 
                           text: viewModel.isDarkMode ? "白天" : "夜间") {
                    viewModel.toggleDayNightMode()
                }
                buttonView(imageName: "textformat", text: "设置") {
                    showSecondLevelSettings = true
                }
            }
            .frame(height: 60)
        }
        .background(viewModel.menuBackgroundColor)
    }
    
    private func chapterButton(text: String, imageName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: imageName)
                    .font(.system(size: 18))
                Text(text)
                    .font(.system(size: 12))
            }
        }
        .frame(width: 60, height: 50)
        .foregroundColor(viewModel.textColor)
    }
    
    private func buttonView(imageName: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(systemName: imageName)
                    .font(.system(size: 24))
                    .frame(height: 30)
                Text(text)
                    .font(.system(size: 14))
                    .frame(height: 20)
            }
        }
        .frame(maxWidth: .infinity)
        .foregroundColor(viewModel.textColor)
    }
    
    private var secondLevelSettingsPanel: some View {
        VStack(spacing: 20) {
            // 亮度滑块
            HStack {
                Image(systemName: "sun.min")
                    .foregroundColor(.gray)
                Slider(value: $viewModel.brightness, in: 0...1)
                    .accentColor(.gray)
                    .frame(height: 30)
                Image(systemName: "sun.max")
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.top, 20)

            // 字体大小和翻页模式
            HStack(spacing: 10) {
                // 字体大小调节
                ZStack {
                    HStack(spacing: 0) {
                        Button(action: { 
                            tempFontSize = max(16, tempFontSize - 1)
                            viewModel.setFontSize(tempFontSize)
                        }) {
                            Text("A-")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.1))
                        
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 0) {
                                    ForEach(16...30, id: \.self) { size in
                                        Text("\(size)")
                                            .font(.system(size: size == Int(tempFontSize) ? 18 : 14))
                                            .foregroundColor(size == Int(tempFontSize) ? .black : .gray)
                                            .fontWeight(size == Int(tempFontSize) ? .bold : .regular)
                                            .frame(width: 50)
                                            .id(size)
                                    }
                                }
                                .frame(height: 40)
                            }
                            .frame(width: 150)
                            .onChange(of: viewModel.fontSize) { newValue in
                                tempFontSize = newValue
                                withAnimation {
                                    proxy.scrollTo(Int(newValue), anchor: .center)
                                }
                            }
                            .onAppear {
                                tempFontSize = viewModel.fontSize
                                proxy.scrollTo(Int(tempFontSize), anchor: .center)
                            }
                            .simultaneousGesture(
                                DragGesture()
                                    .onEnded { value in
                                        let offset = value.translation.width
                                        let newSize = Int(tempFontSize) - Int(offset / 50)
                                        tempFontSize = CGFloat(max(16, min(30, newSize)))
                                        viewModel.setFontSize(tempFontSize)
                                    }
                            )
                        }
                        
                        Button(action: { 
                            tempFontSize = min(30, tempFontSize + 1)
                            viewModel.setFontSize(tempFontSize)
                        }) {
                            Text("A+")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.1))
                    }
                }
                .frame(width: 230, height: 40)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                // 翻页模式
                Button(action: { 
                    showThirdLevelSettings = true
                }) {
                    HStack {
                        Text("翻页")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                }
                .frame(width: 100, height: 40)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)

            // 背景颜色选择
            HStack(spacing: 10) {
                ForEach(viewModel.backgroundColors, id: \.self) { color in
                    Button(action: { 
                        viewModel.backgroundColor = color
                        if color == .black {
                            viewModel.textColor = .white
                        } else {
                            viewModel.textColor = .black
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color)
                            .frame(height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(viewModel.backgroundColor == color ? Color.blue : Color.clear, lineWidth: 2)
                            )
                            .overlay(
                                Image(systemName: "checkmark")
                                    .foregroundColor(color == .black ? .white : .black)
                                    .opacity(viewModel.backgroundColor == color ? 1 : 0)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(Color.white)
    }
    
    private var thirdLevelSettingsPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    showThirdLevelSettings = false
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                }
                Spacer()
                Text("选择翻页方式")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            ForEach(BookReadingViewModel.allPageTurningModes, id: \.self) { mode in
                Button(action: {
                    viewModel.pageTurningMode = mode
                    showThirdLevelSettings = false
                }) {
                    HStack {
                        Text(viewModel.displayName(for: mode))
                            .foregroundColor(.black)
                        Spacer()
                        if viewModel.pageTurningMode == mode {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                }
                Divider()
            }
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
    
    // 修改后的 chapterListView
    var chapterListView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 半透明景，当侧边栏显示时出现
                if viewModel.showChapterList {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation {
                                viewModel.showChapterList = false
                            }
                        }
                }

                // 侧边栏内容
                VStack(spacing: 0) {
                    // 调整顶部间距，使其与阅读界面标栏一致
                    Spacer()
                        .frame(height: 10)

                    // 标题栏
                    HStack {
                        Text("章节列表")
                            .font(.headline)
                        Spacer()
                        // 将“xmark”图标替换为“关闭”文字按钮
                        Button(action: {
                            withAnimation {
                                viewModel.showChapterList = false
                            }
                        }) {
                            Text("关闭")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                    .background(viewModel.backgroundColor)


                    // 章节列表
                    List(viewModel.book.chapters.indices, id: \.self) { index in
                        Button(action: {
                            viewModel.loadChapterFromList(at: index)
                            withAnimation {
                                viewModel.showChapterList = false
                            }
                        }) {
                            Text(viewModel.book.chapters[index].title)
                                .foregroundColor(index == viewModel.chapterIndex ? .blue : .primary)
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.75)
                .background(viewModel.backgroundColor)
                .offset(x: viewModel.showChapterList ? 0 : -geometry.size.width * 0.75)
                .animation(.easeInOut(duration: 0.3), value: viewModel.showChapterList)
            }
        }
        .edgesIgnoringSafeArea([.leading, .trailing, .bottom])
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
                        Slider(value: $tempFontSize, in: 12...32, step: 1) { _ in
                            viewModel.setFontSize(tempFontSize)
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
                            Text("仿真").tag(PageTurningMode.curl)
                            Text("水平滑动").tag(PageTurningMode.horizontal)
                            Text("直接切换").tag(PageTurningMode.direct)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .onAppear {
                    tempFontSize = viewModel.fontSize
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
        
        // 修改初始化方法
        init(book: Book, startingChapter: Int = 0) {
            self.book = book
            self.chapterIndex = startingChapter
            print("BookReadingViewModel initialized with book: \(book.title), startingChapter: \(startingChapter)")
            
            // 加载存的阅读进度
            loadReadingProgress()
        }
        
        func initializeBook(progressUpdate: @escaping (Double) -> Void) {
            print("Initializing book: \(book.title)")
            Task {
                await loadAllChapters(progressUpdate: progressUpdate)
                // 加载指定章节
                loadChapter(at: chapterIndex)
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
        
        func loadChapter(at index: Int, resetPage: Bool = false) {
            print("loadChapter called. Index: \(index), resetPage: \(resetPage)")
            guard index >= 0 && index < book.chapters.count else {
                print("Invalid chapter index: \(index)")
                return
            }
            isChapterLoading = true
            chapterIndex = index

            // 更新 nextChapterTitle
            nextChapterTitle = book.chapters[index].title

            DispatchQueue.main.async {
                self.pages = []
                self.totalPages = 0
                self.currentChapterContent = ""
                if resetPage || !self.initialLoad {
                    self.currentPage = 0
                    print("Reset current page to 0")
                }
            }

            Task {
                await loadChapterContent()
                await MainActor.run {
                    self.isChapterLoading = false
                    self.updateProgressFromCurrentPage()
                    self.saveReadingProgress()
                    self.initialLoad = false
                    print("Chapter loaded. Total pages: \(self.totalPages), Current page: \(self.currentPage)")
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
        
        @MainActor
        func splitContentIntoPages(_ content: String) {
            print("Splitting content into pages. Content length: \(content.count)")
            
            let screenSize = UIScreen.main.bounds.size
            let contentSize = CGSize(width: screenSize.width - 40, height: screenSize.height - 120) // 调整上方和下方的边距
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
            let textLength = attributedString.length
            
            while currentIndex < textLength {
                // 创建用于 CTFramesetter 的范围，确保范围正确
                let range = CFRangeMake(currentIndex, textLength - currentIndex)
                
                let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
                let visibleRange = CTFrameGetVisibleStringRange(frame)
                
                if visibleRange.length == 0 {
                    break // 防止 visibleRange.length 为 0 时陷入死循环
                }
                
                let pageRange = NSRange(location: visibleRange.location, length: visibleRange.length)
                let pageContent = (attributedString.string as NSString).substring(with: pageRange)
                pages.append(pageContent)
                
                currentIndex += visibleRange.length // 正确更新 currentIndex，避免重复
            }
            
            // 过滤掉可能空白页
            self.pages = pages.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            self.totalPages = self.pages.count
            self.updateProgressFromCurrentPage()
            print("Pages after splitting: \(pages.count)")
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
        
        // 新增方法：加载阅读进度
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
            
            // 获取现有的阅读历史
            var readingHistory = UserDefaults.standard.readingHistory()
            
            // 如果已经存在这本书的记录，更新它
            if let index = readingHistory.firstIndex(where: { $0.book.id == book.id }) {
                readingHistory[index] = record
            } else {
                // 否则，添加新记录
                readingHistory.append(record)
            }
            
            // 限制历史记录数量（例如，只保留最近的20条记录）
            if readingHistory.count > 20 {
                readingHistory = Array(readingHistory.suffix(20))
            }
            
            // 保存更新后的阅读历史
            UserDefaults.standard.saveReadingHistory(readingHistory)
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
    
    private func handleTapGesture(location: CGPoint, in geometry: GeometryProxy) {
        let width = geometry.size.width
        let height = geometry.size.height
        
        if location.x < width / 3 {
            // 区域1: 向前翻页
            viewModel.previousPage()
        } else if location.x > width * 2 / 3 {
            // 区域2: 向后翻页
            viewModel.nextPage()
        } else if location.y > height / 3 && location.y < height * 2 / 3 {
            // 区域3: 中央区域，显示/隐藏菜单
            toggleSettingsPanel()
        }
    }

    private func toggleSettingsPanel() {
        if showSettingsPanel {
            showSettingsPanel = false
            showSecondLevelSettings = false
            showThirdLevelSettings = false
        } else {
            showSettingsPanel = true
            viewModel.showChapterList = false
        }
    }

    private var bottomToolbar: some View {
        HStack {
            HStack {
                Image(systemName: "battery.100")
                    .foregroundColor(viewModel.textColor)
                Text("100%")
                    .foregroundColor(viewModel.textColor)
            }
            Spacer()
            Text("\(viewModel.currentPage + 1) / \(viewModel.totalPages)")
                .foregroundColor(viewModel.textColor)
        }
        .font(.footnote)
        .padding(.horizontal)
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




