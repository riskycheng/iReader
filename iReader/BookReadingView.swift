import SwiftUI
import SwiftSoup

// 添加 LoadingPhase 枚举定义
private enum LoadingPhase {
    case none
    case downloading
    case parsing
}

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
    @State private var pageResetTrigger = false // 新：用于触发页面重置
    @State private var showGestureTutorial: Bool = false
    @AppStorage("shouldShowGestureTutorial") private var shouldShowGestureTutorial: Bool = true
    private let showTutorial: Bool
    @State private var showLoadingDialog: Bool = false
    @State private var loadingPhase: LoadingPhase = .none
    @State private var loadingTimer: Timer?
    @State private var phaseStartTime: Date?
    @StateObject private var settingsViewModel = SettingsViewModel()
    @AppStorage("isDayMode") private var isDayMode: Bool = true
    @AppStorage("selectedBackgroundColor") private var selectedBackgroundColorIndex: Int = 0
    @AppStorage("lastSelectedBackgroundColorIndex") private var lastSelectedBackgroundColorIndex: Int = 0 // 记住上次选择的背景色
    @Environment(\.colorScheme) var colorScheme
    
    init(book: Book, isPresented: Binding<Bool>, startingChapter: Int = 0, showTutorial: Bool = true, shouldSaveProgress: Bool = true) {
        print("\n===== 初始化阅读视图 =====")
        print("书籍标题: \(book.title)")
        print("起始章节: \(startingChapter)")
        print("章节链接: \(book.chapters[startingChapter].link)")
        _isPresented = isPresented
        self.showTutorial = showTutorial
        
        // 获取系统当前的外观模式
        let currentColorScheme = UITraitCollection.current.userInterfaceStyle
        let isSystemInDarkMode = currentColorScheme == .dark
        
        // 获取保存的设置
        let savedColorIndex = UserDefaults.standard.integer(forKey: "selectedBackgroundColor")
        let savedFontSize = UserDefaultsManager.shared.getFontSize()
        
        // 只有在需要保存进度时才加载保存的阅读进度
        var savedChapter = startingChapter
        var savedPage = 0
        
        if shouldSaveProgress {
            if let savedProgress = UserDefaults.standard.dictionary(forKey: "readingProgress_\(book.id)") {
                savedChapter = savedProgress["chapterIndex"] as? Int ?? startingChapter
                savedPage = savedProgress["currentPage"] as? Int ?? 0
                print("找到保存的进度 - 章节: \(savedChapter), 页码: \(savedPage)")
            }
        }
        
        print("加载保存的字体大小: \(savedFontSize)")
        
        // 创建 ViewModel 实例
        let viewModel = BookReadingViewModel(
            book: book,
            startingChapter: savedChapter,
            startingPage: savedPage,
            initialFontSize: savedFontSize,
            shouldSaveProgress: shouldSaveProgress,
            isDayMode: !isSystemInDarkMode,  // 根据系统模式设置
            savedColorIndex: savedColorIndex
        )
        
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 将背景颜色应用到最外 ZStack
                viewModel.backgroundColor
                    .edgesIgnoringSafeArea(.all) // 确保背景颜色覆盖整个屏幕
                
                if isParsing || viewModel.isLoading || viewModel.isChapterLoading {
                    // 添加一个简单的loading提示
                    if !showLoadingDialog {  // 当还没显示对话框时显示简单提示
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(viewModel.textColor)
                            Text("加载中...")
                                .font(.system(size: 14))
                                .foregroundColor(viewModel.textColor)
                        }
                    } else {
                        loadingDialogView
                    }
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.pages.isEmpty && !isParsing && !viewModel.isLoading && !viewModel.isChapterLoading {
                    // 只有在不是加载状态且页面为空时才显示"暂无内容"
                    emptyContentView
                } else {
                    bookContent(in: geometry)
                }
                
                // 将侧边栏覆盖在内容之上
                chapterListView
            }
            .navigationBarHidden(true)
            .preferredColorScheme(viewModel.isSystemInDarkMode ? .dark : .light)
            .onAppear {
                startInitialLoading()
                // 添加阅读记录
                if let currentChapter = viewModel.book.chapters[safe: viewModel.chapterIndex] {
                    settingsViewModel.addReadingRecord(
                        viewModel.book,
                        lastChapter: currentChapter.title
                    )
                }
                
                // 初始化时设置系统暗黑模式状态
                let isSystemDark = colorScheme == .dark
                viewModel.isSystemInDarkMode = isSystemDark
                
                // 根据系统模式设置背景色
                if isSystemDark {
                    // 系统是暗黑模式时，强制使用黑色背景
                    viewModel.backgroundColor = .black
                    viewModel.textColor = .white
                } else {
                    // 系统是亮色模式时，使用保存的背景色
                    let savedColorIndex = selectedBackgroundColorIndex
                    viewModel.backgroundColor = viewModel.backgroundColors[savedColorIndex]
                    viewModel.textColor = UIColor(viewModel.backgroundColor).brightness < 0.5 ? .white : .black
                }
            }
            .onChange(of: viewModel.isLoading) { newValue in
                handleLoadingStateChange(isLoading: newValue, phase: .downloading)
            }
            .onChange(of: viewModel.isChapterLoading) { newValue in
                handleLoadingStateChange(isLoading: newValue, phase: .parsing)
            }
            .onChange(of: viewModel.chapterIndex) { newIndex in
                // 当章节改变时更新阅读记录
                if let currentChapter = viewModel.book.chapters[safe: newIndex] {
                    settingsViewModel.addReadingRecord(
                        viewModel.book,
                        lastChapter: currentChapter.title
                    )
                }
            }
            .onDisappear {
                // 取消所有计时器
                loadingTimer?.invalidate()
                loadingTimer = nil
                
                // 确保解析状态被重置
                isParsing = false
                showLoadingDialog = false
                loadingPhase = .none
                phaseStartTime = nil
            }
            .onChange(of: colorScheme) { newColorScheme in
                let isSystemDark = newColorScheme == .dark
                viewModel.isSystemInDarkMode = isSystemDark
                
                // 根据系统模式设置背景色
                if isSystemDark {
                    // 系统切换到暗黑模式时，强制使用黑色背景
                    viewModel.backgroundColor = .black
                    viewModel.textColor = .white
                } else {
                    // 系统切换到亮色模式时，使用保存的背景色
                    let savedColorIndex = selectedBackgroundColorIndex
                    viewModel.backgroundColor = viewModel.backgroundColors[savedColorIndex]
                    viewModel.textColor = UIColor(viewModel.backgroundColor).brightness < 0.5 ? .white : .black
                }
            }
        }
    }
    
    private var loadingDialogView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(loadingPhase == .downloading ? "正在下载章节..." : "正在解析章节...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("请稍候，马上就好")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                if loadingPhase == .downloading {
                    Text(String(format: "%.0f%%", min(self.parsingProgress * 100, 100.0)))
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                        .frame(height: 20)
                }
                
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("取消")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
            }
            .frame(width: 200, height: 200)
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(15)
        }
    }
    
    private func handleLoadingStateChange(isLoading: Bool, phase: LoadingPhase) {
        if isLoading {
            // 开始加载时，设置2秒后显示加载对话框
            loadingTimer?.invalidate()
            loadingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                withAnimation {
                    self.showLoadingDialog = true
                    self.loadingPhase = phase
                    self.phaseStartTime = Date()
                }
            }
        } else {
            // 加载结束时，检查是否需要延迟隐藏对话框
            if let startTime = phaseStartTime {
                let elapsedTime = Date().timeIntervalSince(startTime)
                if elapsedTime < 2.0 {
                    // 如果显示时间不足2秒，延迟隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + (2.0 - elapsedTime)) {
                        withAnimation {
                            self.showLoadingDialog = false
                            self.loadingPhase = .none
                            self.phaseStartTime = nil
                        }
                    }
                } else {
                    // 如果已经显示超过2秒，直接隐藏
                    withAnimation {
                        self.showLoadingDialog = false
                        self.loadingPhase = .none
                        self.phaseStartTime = nil
                    }
                }
            }
            loadingTimer?.invalidate()
            loadingTimer = nil
        }
    }
    
    private func startInitialLoading() {
        print("\n===== 开始解析章节内容 =====")
        print("当前章节: \(viewModel.book.chapters[viewModel.chapterIndex].title)")
        print("章节链接: \(viewModel.book.chapters[viewModel.chapterIndex].link)")
        
        // 这里是启动2秒计时器的代码
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation {
                self.showLoadingDialog = true
                self.loadingPhase = .downloading
                self.phaseStartTime = Date()
            }
        }
        
        // 添加超时处理
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            // 如果30秒后仍在解析状态，则认为解析失败
            if self.isParsing {
                print("\n===== 解析超时 =====")
                withAnimation {
                    self.isParsing = false
                    self.showLoadingDialog = false
                    self.loadingPhase = .none
                    self.phaseStartTime = nil
                    // 设置错误信息
                    self.viewModel.errorMessage = "加载超时，请检查网络连接或稍后再试"
                }
                self.loadingTimer?.invalidate()
                self.loadingTimer = nil
            } else {
                withAnimation {
                    self.isParsing = false
                    self.showLoadingDialog = false
                    self.loadingPhase = .none
                    self.phaseStartTime = nil
                }
            }
        }
        
        viewModel.initializeBook { progress in
            self.parsingProgress = progress
            if progress >= 1.0 {
                // 完成时检查是否需要延迟隐藏
                if let startTime = self.phaseStartTime {
                    let elapsedTime = Date().timeIntervalSince(startTime)
                    if elapsedTime < 2.0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + (2.0 - elapsedTime)) {
                            withAnimation {
                                self.isParsing = false
                                self.showLoadingDialog = false
                                self.loadingPhase = .none
                                self.phaseStartTime = nil
                            }
                        }
                    } else {
                        withAnimation {
                            self.isParsing = false
                        }
                    }
                } else {
                    withAnimation {
                        self.isParsing = false
                    }
                }
                self.loadingTimer?.invalidate()
                self.loadingTimer = nil
                // 解析完成，取消超时计时器
                timeoutTimer.invalidate()
            }
        }
        
        if showTutorial && shouldShowGestureTutorial {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showGestureTutorial = true
                }
            }
        }
    }
    
    private func errorView(_ errorMessage: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("加载出错")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if let currentChapter = viewModel.book.chapters[safe: viewModel.chapterIndex] {
                    Text("当前章节: \(currentChapter.title)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("链接: \(currentChapter.link)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    print("\n===== 重试加载章节 =====")
                    print("重试章节: \(viewModel.book.chapters[viewModel.chapterIndex].title)")
                    print("重试链接: \(viewModel.book.chapters[viewModel.chapterIndex].link)")
                    viewModel.retryLoadCurrentChapter()
                }) {
                    Text("重试")
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("返回")
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color.gray)
                        .cornerRadius(8)
                }
            }
            .padding(.top, 10)
        }
        .padding(30)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
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
                
                // 添加返回按钮
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("返回")
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color.gray)
                        .cornerRadius(8)
                }
                .padding(.top, 10)
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
                            viewModel.updateProgressFromCurrentPage()
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
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 5)
                        .background(viewModel.backgroundColor)
                        
                        // Page content
                        pageView(for: index, in: geometry)
                            .frame(maxHeight: .infinity)
                        
                        Spacer(minLength: 0) // 添加这，使 footer 尽可能靠近底部
                        
                        // Footer
                        bottomToolbar
                            .background(menuBackgroundColor)
                            .frame(height: 10)
                            .background(menuBackgroundColor)
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
            
            // 添加顶部菜单覆层
            if showSettingsPanel {
                topMenuOverlay
                    .transition(.move(edge: .top))
            }
            
            // 设置悬层
            settingsOverlay(in: geometry)
            
            // 添加手势教程蒙
            if showGestureTutorial {
                gestureTutorialOverlay(in: geometry)
                    .transition(.opacity)
            }
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
        .background(menuBackgroundColor)
        .offset(y: showSettingsPanel ? 0 : geometry.size.height)
        .animation(.none)
    }
    
    private func pageView(for index: Int, in geometry: GeometryProxy) -> some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                if index >= 0 && index < viewModel.pages.count {
                    if index == 0 {
                        let titleFontSize = viewModel.fontSize * 1.2
                        Text(viewModel.book.chapters[viewModel.chapterIndex].title)
                            .font(.custom(viewModel.fontFamily, size: titleFontSize))
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.textColor)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                    }
                    
                    let contentFontSize = viewModel.fontSize
                    Text(viewModel.pages[index])
                        .font(.custom(viewModel.fontFamily, size: contentFontSize))
                        .foregroundColor(viewModel.textColor)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 20)
                        .padding(.top, index == 0 ? 10 : 15)
                        .padding(.bottom, 2)
                } else {
                    let loadingFontSize = viewModel.fontSize
                    Text("加载中...")
                        .font(.custom(viewModel.fontFamily, size: loadingFontSize))
                        .foregroundColor(viewModel.textColor)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height - 40)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(viewModel.backgroundColor)
        }
    }
    
    private var settingsPanel: some View {
        VStack(spacing: 0) {
            // 第一：上一章、滑动、下一章
            HStack {
                chapterButton(text: "上一章", imageName: "chevron.left") {
                    viewModel.previousChapter()
                }
                
                CustomSlider(value: $viewModel.chapterProgress, range: 0...1) { _ in
                    // 移除这里的 updateCurrentPageFromProgress 用
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
            
            // 第二：目录、日/夜间模式和设
            HStack(spacing: 0) {
                buttonView(imageName: "list.bullet", text: "目录") {
                    withAnimation {
                        viewModel.showChapterList.toggle()
                        showSettingsPanel = false
                    }
                }
                buttonView(imageName: viewModel.isSystemInDarkMode ? "sun.max.fill" : "moon.fill",
                           text: viewModel.isSystemInDarkMode ? "白天" : "夜间") {
                    withAnimation {
                        // 切换系统暗黑模式状态
                        viewModel.isSystemInDarkMode.toggle()
                        
                        if viewModel.isSystemInDarkMode {
                            // 切换到暗黑模式：强制使用黑色背景
                            viewModel.backgroundColor = .black
                            viewModel.textColor = .white
                        } else {
                            // 切换到亮色模式：使用保存的背景色
                            let savedColorIndex = selectedBackgroundColorIndex
                            viewModel.backgroundColor = viewModel.backgroundColors[savedColorIndex]
                            viewModel.textColor = UIColor(viewModel.backgroundColor).brightness < 0.5 ? .white : .black
                        }
                    }
                }
                buttonView(imageName: "textformat", text: "设置") {
                    showSecondLevelSettings = true
                }
            }
            .frame(height: 60)
        }
        .background(menuBackgroundColor)
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
        Button(action: {
            print("点击了按钮: \(text)")
            action()
        }) {
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
            // 亮度滑块 - 修复亮度调节
            HStack {
                Image(systemName: "sun.min")
                    .foregroundColor(viewModel.textColor)
                Slider(
                    value: $viewModel.brightness,
                    in: 0...1,
                    onEditingChanged: { isEditing in
                        // 当滑动结束时保存亮度设置
                        if !isEditing {
                            UserDefaults.standard.set(viewModel.brightness, forKey: "screenBrightness")
                        }
                        // 实时更新屏幕亮度
                        UIScreen.main.brightness = CGFloat(viewModel.brightness)
                    }
                )
                .accentColor(viewModel.textColor)
                Image(systemName: "sun.max")
                    .foregroundColor(viewModel.textColor)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // 字体大小和字体选择 - 调整布局
            HStack(spacing: 10) {
                // 字体大小调节
                HStack(spacing: 0) {
                    Button(action: {
                        print("\n===== 减小字体大小 =====")
                        print("当前字体大小: \(tempFontSize)")
                        tempFontSize = max(16, tempFontSize - 1)
                        print("调整后字体大小: \(tempFontSize)")
                        viewModel.setFontSize(tempFontSize)
                        UserDefaultsManager.shared.saveFontSize(tempFontSize)
                        viewModel.splitContentIntoPages(viewModel.currentChapterContent)
                        print("========================\n")
                    }) {
                        Text("A-")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(viewModel.textColor)
                    }
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.1))
                    
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(16...30, id: \.self) { size in
                                    Text("\(size)")
                                        .font(.system(size: size == Int(tempFontSize) ? 18 : 14))
                                        .foregroundColor(size == Int(tempFontSize) ? viewModel.textColor : viewModel.textColor.opacity(0.5))
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
                    }
                    
                    Button(action: {
                        print("\n===== 增加字体大小 =====")
                        print("当前字体大小: \(tempFontSize)")
                        tempFontSize = min(30, tempFontSize + 1)
                        print("调整后字体大小: \(tempFontSize)")
                        viewModel.setFontSize(tempFontSize)
                        UserDefaultsManager.shared.saveFontSize(tempFontSize)
                        viewModel.splitContentIntoPages(viewModel.currentChapterContent)
                        print("========================\n")
                    }) {
                        Text("A+")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(viewModel.textColor)
                    }
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.1))
                }
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // 字体选择按钮
                Button(action: {
                    showThirdLevelSettings = true
                }) {
                    HStack {
                        Text("字体")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.textColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(viewModel.textColor.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // 背景颜色选择
            HStack(spacing: 10) {
                ForEach(Array(viewModel.backgroundColors.enumerated()), id: \.element) { index, color in
                    Button(action: {
                        viewModel.backgroundColor = color
                        if UIColor(color).brightness < 0.5 {
                            viewModel.textColor = .white
                        } else {
                            viewModel.textColor = .black
                        }
                        selectedBackgroundColorIndex = index
                        UserDefaults.standard.set(index, forKey: "selectedBackgroundColor")
                        
                        // 如果在日间模式下才允许改变背景色
                        if isDayMode {
                            lastSelectedBackgroundColorIndex = index
                            UserDefaults.standard.set(index, forKey: "lastSelectedBackgroundColorIndex")
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedBackgroundColorIndex == index && isDayMode ? Color.blue : Color.clear, lineWidth: 2)
                            )
                            .overlay(
                                Image(systemName: "checkmark")
                                    .foregroundColor(UIColor(color).brightness < 0.5 ? .white : .black)
                                    .opacity(selectedBackgroundColorIndex == index && isDayMode ? 1 : 0)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(menuBackgroundColor)
        .onAppear {
            // 加载保存的亮度设置
            let savedBrightness = UserDefaults.standard.float(forKey: "screenBrightness")
            if savedBrightness == 0 {
                // 果没有保存的设置，使用当前系统亮度
                viewModel.brightness = Double(UIScreen.main.brightness)
            } else {
                viewModel.brightness = Double(savedBrightness)
            }
        }
    }
    
    private var thirdLevelSettingsPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    showThirdLevelSettings = false
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                        .imageScale(.large)
                        .frame(width: 44, height: 44) // 增大点击区域
                }
                .padding(.leading, 8)
                
                Spacer()
                Text("选字体")
                    .font(.headline)
                Spacer()
                
                // 添加一个占位视图保持标题居中
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            
            // 字体列表
            VStack(spacing: 0) {
                ForEach(viewModel.availableFonts.dropLast(), id: \.self) { font in
                    Button(action: {
                        viewModel.currentFont = font
                        viewModel.fontFamily = font.fontName  // 更新 fontFamily
                        viewModel.splitContentIntoPages(viewModel.currentChapterContent) // 立即重新分页
                        showThirdLevelSettings = false
                    }) {
                        HStack {
                            Text("春暖花开")  
                                .font(.custom(font.fontName, size: 17))
                                .foregroundColor(.black)
                            Spacer()
                            Text(font.name)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            if viewModel.currentFont.fontName == font.fontName {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(.horizontal)
                        .frame(height: 50)
                    }
                    Divider()
                }
            }
        }
        .frame(height: 320)
        .background(menuBackgroundColor)
    }
    
    // 修改后的 chapterListView
    var chapterListView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 透明背景
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
                    // 书籍信息头部
                    VStack(spacing: 8) {
                        // 修改 HStack 的 alignment 为 .center
                        HStack(alignment: .center, spacing: 12) {
                            // 封面图
                            AsyncImage(url: URL(string: viewModel.book.coverURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 80, height: 106)
                            .cornerRadius(6)
                            .shadow(radius: 2)
                            
                            // 右侧：书籍标题和作
                            VStack(alignment: .leading, spacing: 0) {
                                Text(viewModel.book.title)
                                    .font(.headline)
                                    .foregroundColor(viewModel.textColor)
                                
                                Spacer()
                                    .frame(height: 12)
                                
                                Text("\(viewModel.book.author)")
                                    .font(.subheadline)
                                    .foregroundColor(viewModel.textColor.opacity(0.7))
                            }
                            
                            Spacer()
                        }
                        
                        // 章节数量和排序按钮
                        HStack {
                            Text("共\(viewModel.book.chapters.count)章")
                                .font(.caption)
                                .foregroundColor(viewModel.textColor.opacity(0.5))
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.isChapterListReversed.toggle()
                            }) {
                                Image(systemName: viewModel.isChapterListReversed ? "arrow.up" : "arrow.down")
                                    .foregroundColor(viewModel.textColor.opacity(0.5))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(viewModel.backgroundColor)
                    
                    Divider()
                    
                    // 章节列表
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                let filteredChapters = viewModel.book.chapters.enumerated()
                                    .filter { !$0.element.title.contains("---展开全部章节---") }
                                
                                let chaptersToDisplay = viewModel.isChapterListReversed ? 
                                    Array(filteredChapters.reversed()) : 
                                    Array(filteredChapters)
                                
                                ForEach(chaptersToDisplay, id: \.element.title) { enumerated in
                                    let (displayIndex, chapter) = enumerated
                                    // 查找章节的原始索引
                                    let originalIndex = viewModel.book.chapters.firstIndex(where: { $0.title == chapter.title }) ?? displayIndex
                                    
                                    Button(action: {
                                        print("\n===== 正在加载章节 =====")
                                        print("章节标题: \(chapter.title)")
                                        print("章节链接: \(chapter.link)")
                                        viewModel.loadChapterFromList(at: originalIndex)
                                        withAnimation {
                                            viewModel.showChapterList = false
                                        }
                                    }) {
                                        HStack {
                                            Text("\(displayIndex + 1).")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(viewModel.textColor.opacity(0.6))
                                                .frame(width: 50, alignment: .leading)
                                            
                                            Text(chapter.title)
                                                .lineLimit(1)
                                                .font(.system(size: 15, weight: originalIndex == viewModel.chapterIndex ? .medium : .regular))
                                            
                                            Spacer()
                                            
                                            if originalIndex == viewModel.chapterIndex {
                                                Text("当前")
                                                    .font(.caption)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.blue.opacity(0.1))
                                                    .cornerRadius(4)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                    }
                                    .id(originalIndex)
                                    .foregroundColor(originalIndex == viewModel.chapterIndex ? .blue : viewModel.textColor)
                                    .background(originalIndex == viewModel.chapterIndex ?
                                                Color.blue.opacity(0.05) :
                                                    Color.clear)
                                }
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.82)
                .background(viewModel.backgroundColor)
                .offset(x: viewModel.showChapterList ? 0 : -geometry.size.width * 0.82)
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
                    Section(header: Text("字体小")) {
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
                            Text("仿").tag(PageTurningMode.curl)
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
    
    private var topMenuOverlay: some View {
        VStack {
            // 顶部菜单栏
            HStack(spacing: 0) {  // 设 spacing 为 0 以便好地控制布局
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                    }
                    .font(.headline)
                    .foregroundColor(viewModel.textColor)
                }
                
                Spacer()
                
                // 章节标题居中显示
                Text(viewModel.book.chapters[viewModel.chapterIndex].title)
                    .font(.system(size: 24))
                    .foregroundColor(viewModel.textColor)
                    .lineLimit(1)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 50)  // 在两侧添加padding以避免与其他元素重叠
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(menuBackgroundColor)
            
            Spacer()
        }
    }
    
    private func handleTapGesture(location: CGPoint, in geometry: GeometryProxy) {
        let width = geometry.size.width
        let height = geometry.size.height
        
        if location.x < width / 3 {
            // 区域1: 向翻页
            viewModel.previousPage()
        } else if location.x > width * 2 / 3 {
            // 区域2: 向后翻页
            viewModel.nextPage()
        } else if location.y > height / 3 && location.y < height * 2 / 3 {
            // 区域3: 中区域，显示/隐藏菜单
            withAnimation(.easeInOut(duration: 0.3)) {
                toggleSettingsPanel()
            }
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
        .frame(height: 30)
        .background(viewModel.backgroundColor)
    }
    
    // 修改 menuBackgroundColor 计算属性
    private var menuBackgroundColor: Color {
        let backgroundColor = viewModel.backgroundColor
        if backgroundColor == .black {
            // 黑色背景时使用深灰色
            return Color(white: 0.15)
        } else if backgroundColor == .white {
            // 白色背景时使用更深的灰色以分
            return Color(white: 0.93) // 调整为更深的灰色
        } else {
            // 其他颜色时，根据背景色的亮度调整
            let uiColor = UIColor(backgroundColor)
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            
            uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            
            // 调整对比度
            let adjustedBrightness = brightness < 0.5 
                ? min(brightness + 0.15, 1.0)  // 深色背景时变得更亮
                : max(brightness - 0.15, 0.0)  // 浅色背景时变得更暗
            
            return Color(UIColor(hue: hue,
                               saturation: saturation * 0.8, // 降低饱和度使颜色更柔和
                               brightness: adjustedBrightness,
                               alpha: alpha))
        }
    }
    
    // 修改 gestureTutorialOverlay 函数
    private func gestureTutorialOverlay(in geometry: GeometryProxy) -> some View {
        ZStack {
            // 深色背景遮罩
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            // 主要内容区域
            VStack(spacing: 30) {
                // 顶部标题区域
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text("阅读手势指南")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                )
                .padding(.horizontal, 20)
                .padding(.top, 40)
                
                // 手势区域指示 (保持原来设计)
                HStack(spacing: 0) {
                    // 左侧区域 - 上一页
                    GestureArea(
                        icon: "chevron.backward.circle.fill",
                        title: "上一页",
                        description: "点击左侧区域",
                        color: .blue
                    )
                    
                    // 中间区域 - 菜单
                    GestureArea(
                        icon: "hand.tap.fill",
                        title: "菜单",
                        description: "击中央区域",
                        color: .orange
                    )
                    
                    // 右侧区域 - 下一页
                    GestureArea(
                        icon: "chevron.forward.circle.fill",
                        title: "下一页",
                        description: "点击右侧区域",
                        color: .blue
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 底部控制区域
                VStack(spacing: 25) {
                    // 不再提示选项 - 重新设计
                    HStack {
                        Toggle("", isOn: .init(
                            get: { !shouldShowGestureTutorial },
                            set: { shouldShowGestureTutorial = !$0 }
                        ))
                        .labelsHidden()
                        .scaleEffect(0.8)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        
                        Text("不再显示手势指南")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(.horizontal, 40)
                    
                    // 开始阅读按钮 (保持原来的设计)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showGestureTutorial = false
                        }
                    }) {
                        Text("开始阅读")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 160, height: 44)
                            .background(
                                Capsule()
                                    .fill(Color.blue)
                                    .shadow(color: .blue.opacity(0.5), radius: 8, x: 0, y: 4)
                            )
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .transition(.opacity)
    }
    
    // 新增手势区域组件
    private struct GestureArea: View {
        let icon: String
        let title: String
        let description: String
        let color: Color
        
        var body: some View {
            VStack {
                // 区背景
                VStack(spacing: 16) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: icon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(color)
                    }
                    
                    // 文字说明
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        
                        Text(description)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.systemBackground).opacity(0.95))
                )
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// 将扩展移到文作用域
extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            try await values.append(transform(element))
        }
        return values
    }
}

// 在文件底部添加扩展
extension UIColor {
    var brightness: CGFloat {
        var white: CGFloat = 0
        getWhite(&white, alpha: nil)
        return white
    }
}



