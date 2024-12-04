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
    @State private var pageResetTrigger = false // 新：用于触发页面重置
    
    // 修改后的初始化方法，增加 `startingChapter` 参数，默认值为 0
    init(book: Book, isPresented: Binding<Bool>, startingChapter: Int = 0) {
        print("初始化 BookReadingView - 书籍: \(book.title)")
        _isPresented = isPresented
        
        // 加载保存的阅读进度
        var savedChapter = startingChapter
        var savedPage = 0
        
        if let savedProgress = UserDefaults.standard.dictionary(forKey: "readingProgress_\(book.id)") {
            savedChapter = savedProgress["chapterIndex"] as? Int ?? startingChapter
            savedPage = savedProgress["currentPage"] as? Int ?? 0
            print("找到保存的进度 - 章节: \(savedChapter), 页码: \(savedPage)")
        }
        
        // 加载保存的字体大小
        let savedFontSize = UserDefaultsManager.shared.getFontSize()
        print("加载保存的字体大小: \(savedFontSize)")
        
        // 使用保存的进度和字体大小初始化 ViewModel
        _viewModel = StateObject(wrappedValue: BookReadingViewModel(
            book: book,
            startingChapter: savedChapter,
            startingPage: savedPage,
            initialFontSize: savedFontSize
        ))
        
        // 初始化临时字体大小
        _tempFontSize = State(initialValue: savedFontSize)
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
            // 每次页面改变时保存进度
            viewModel.saveReadingProgress()
        }
        .onChange(of: viewModel.chapterIndex) { _ in
            // 每次章节改变时保存进度
            viewModel.saveReadingProgress()
        }
        .onDisappear {
            // 退出时保存进度
            viewModel.saveReadingProgress()
            viewModel.recordReadingHistory()
            viewModel.clearPreloadCache()
        }
    }
    
    private var parsingView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("正在下载章节...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("请稍候，马上就好")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(String(format: "%.0f%%", min(self.parsingProgress * 100, 100.0)))
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                    .frame(height: 20)
                
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
    
    private var loadingView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("正在解析章节...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("请稍候，马上就好")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Text("")
                    .font(.headline)
                    .frame(height: 20)
                
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
    
    private func errorView(_ errorMessage: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("加载出错")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("返回")
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
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
                            .background(viewModel.backgroundColor)
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

            // 添加顶部菜单覆盖层
            if showSettingsPanel {
                topMenuOverlay
                    .transition(.move(edge: .top))
            }

            // 设置悬层
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
                            .onAppear {
                                print("应用章节标题字体大小: \(titleFontSize)")
                            }
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
                        .onAppear {
                            print("应用正文字体大小: \(contentFontSize)")
                        }
                } else {
                    let loadingFontSize = viewModel.fontSize
                    Text("加载中...")
                        .font(.custom(viewModel.fontFamily, size: loadingFontSize))
                        .foregroundColor(viewModel.textColor)
                        .onAppear {
                            print("应用加载中视图字体大小: \(loadingFontSize)")
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height - 40)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(viewModel.backgroundColor)
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
            
            // 第二：目录、日/夜间模式和设
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

            // 字体大和翻页模式
            HStack(spacing: 10) {
                // 字体小
                ZStack {
                    HStack(spacing: 0) {
                        Button(action: { 
                            print("\n===== 减小字体大小 =====")
                            print("当前字体大小: \(tempFontSize)")
                            tempFontSize = max(16, tempFontSize - 1)
                            print("调整后字体大小: \(tempFontSize)")
                            viewModel.setFontSize(tempFontSize)
                            UserDefaultsManager.shared.saveFontSize(tempFontSize)
                            // 重新分页
                            viewModel.splitContentIntoPages(viewModel.currentChapterContent)
                            print("========================\n")
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
                                print("\n===== 视图加载 =====")
                                print("初始字体大小: \(tempFontSize)")
                                print("===================\n")
                            }
                            .simultaneousGesture(
                                DragGesture()
                                    .onEnded { value in
                                        print("\n===== 拖动调整字体大小 =====")
                                        print("拖动前字体大小: \(tempFontSize)")
                                        let offset = value.translation.width
                                        let newSize = Int(tempFontSize) - Int(offset / 50)
                                        tempFontSize = CGFloat(max(16, min(30, newSize)))
                                        print("拖动后字体小: \(tempFontSize)")
                                        viewModel.setFontSize(tempFontSize)
                                        UserDefaultsManager.shared.saveFontSize(tempFontSize)
                                        // 重新分页
                                        viewModel.splitContentIntoPages(viewModel.currentChapterContent)
                                        print("===========================\n")
                                    }
                            )
                        }
                        
                        Button(action: { 
                            print("\n===== 增加字体大小 =====")
                            print("当前字体大小: \(tempFontSize)")
                            tempFontSize = min(30, tempFontSize + 1)
                            print("调整后字体大小: \(tempFontSize)")
                            viewModel.setFontSize(tempFontSize)
                            UserDefaultsManager.shared.saveFontSize(tempFontSize)
                            // 新分页
                            viewModel.splitContentIntoPages(viewModel.currentChapterContent)
                            print("========================\n")
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

                // 将翻页模式按钮替换为字体选择按钮
                Button(action: { 
                    showThirdLevelSettings = true
                }) {
                    HStack {
                        Text("字体")
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

            // 背景颜色选
            HStack(spacing: 10) {
                ForEach(Array(viewModel.backgroundColors.enumerated()), id: \.element) { index, color in
                    Button(action: { 
                        viewModel.backgroundColor = color
                        if color == .black {
                            viewModel.textColor = .white
                        } else {
                            viewModel.textColor = .black
                        }
                        // 保存选中的颜色索引
                        UserDefaultsManager.shared.saveSelectedBackgroundColorIndex(index)
                        print("保存背景颜色索引: \(index)")
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
        .background(menuBackgroundColor)
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
                Text("选择字体")
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
                ForEach(viewModel.availableFonts) { font in
                    Button(action: {
                        viewModel.currentFont = font
                        viewModel.fontFamily = font.fontName  // 更新 fontFamily
                        viewModel.splitContentIntoPages(viewModel.currentChapterContent) // 立即重新分
                        showThirdLevelSettings = false
                    }) {
                        HStack {
                            Text("春暖花开")  // 使用示例中文文本
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
                // 半透明背景
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
                            
                            // 右侧：书籍标题和作者
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
                                ForEach(viewModel.isChapterListReversed ? 
                                       Array(viewModel.book.chapters.indices.reversed()) : 
                                       Array(viewModel.book.chapters.indices), 
                                       id: \.self) { index in
                                    Button(action: {
                                        viewModel.loadChapterFromList(at: index)
                                        withAnimation {
                                            viewModel.showChapterList = false
                                        }
                                    }) {
                                        HStack {
                                            Text("\(index + 1).")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(viewModel.textColor.opacity(0.6))
                                                .frame(width: 50, alignment: .leading)
                                            
                                            Text(viewModel.book.chapters[index].title)
                                                .lineLimit(1)
                                                .font(.system(size: 15, weight: index == viewModel.chapterIndex ? .medium : .regular))
                                            
                                            Spacer()
                                            
                                            if index == viewModel.chapterIndex {
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
                                    .id(index)
                                    .foregroundColor(index == viewModel.chapterIndex ? .blue : viewModel.textColor)
                                    .background(index == viewModel.chapterIndex ? 
                                              Color.blue.opacity(0.05) : 
                                              Color.clear)
                                }
                            }
                        }
                        .background(Color(UIColor.systemGray6))
                        .onChange(of: viewModel.showChapterList) { newValue in
                            if newValue {
                                withAnimation {
                                    proxy.scrollTo(viewModel.chapterIndex, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.82)
                .background(Color(UIColor.systemGray6))
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
                    
                    Section(header: Text("翻���模式")) {
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
            HStack(spacing: 0) {  // 设置 spacing 为 0 以便更好地控制布局
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
            // 区域1: 向前翻页
            viewModel.previousPage()
        } else if location.x > width * 2 / 3 {
            // 区域2: 向后翻页
            viewModel.nextPage()
        } else if location.y > height / 3 && location.y < height * 2 / 3 {
            // 区域3: 中央区域，显示/隐藏菜单
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

    // 在 BookReadingView 中添加一个计算属性
    private var menuBackgroundColor: Color {
        if viewModel.backgroundColor == .black {
            // 如果背景是黑色，返回深灰色
            return Color(white: 0.15)
        } else if viewModel.backgroundColor == .white {
            // 如果背景是白色，返回略亮的白色
            return Color(white: 0.98)
        } else {
            // 对于其他颜色，增加亮度
            let uiColor = UIColor(viewModel.backgroundColor)
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            
            uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            
            // 增加亮度，但不超过1.0
            let adjustedBrightness = min(brightness + 0.1, 1.0)
            
            return Color(UIColor(hue: hue, 
                               saturation: saturation, 
                               brightness: adjustedBrightness, 
                               alpha: alpha))
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






