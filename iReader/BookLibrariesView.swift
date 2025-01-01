import SwiftUI

struct BookLibrariesView: View {
    @StateObject private var viewModel = BookLibrariesViewModel()
    @EnvironmentObject private var libraryManager: LibraryManager
    @Binding var selectedBook: Book?
    @Binding var isShowingBookReader: Bool
    @Binding var selectedTab: Int
    @State private var bookForInfo: Book?
    @State private var bookToRemove: Book?
    @State private var showingRemoveConfirmation = false
    @State private var isPulling = false
    @State private var pullProgress: CGFloat = 0
    @State private var isRotating = false
    @State private var selectedBookForMenu: Book?
    @State private var showActionMenu = false
    @State private var showingBookInfo = false
    @State private var pressedBookId: UUID? = nil
    @State private var selectedBookForAnimation: Book? = nil
    @State private var isAnimating = false
    @State private var showingCustomRemoveAlert = false
    @State private var bookCovers: [UUID: Image] = [:]
    @State private var booksWithUpdates: Set<UUID> = []
    @State private var isBackgroundRefreshing = false
    @State private var downloadingCovers: Set<UUID> = []
    @AppStorage("autoCheckUpdate") private var autoCheckUpdate = true
    @AppStorage("checkUpdateInterval") private var checkUpdateInterval = 30
    @State private var updateCheckTimer: Timer?
    @State private var isLoadingChapters = false
    @State private var loadingChapterBookId: UUID? = nil
    
    private func checkUpdatesInBackground() async {
        guard !isBackgroundRefreshing else { return }
        isBackgroundRefreshing = true
        
        for book in viewModel.books {
            do {
                let hasUpdate = await viewModel.checkBookUpdate(book)
                if hasUpdate {
                    await MainActor.run {
                        withAnimation {
                            booksWithUpdates.insert(book.id)
                        }
                        libraryManager.saveUpdateStatus(for: book.id, hasUpdate: true)
                    }
                    await viewModel.refreshSingleBook(book)
                    HapticManager.shared.successFeedback()
                }
            } catch {
                print("检查更新失败: \(error.localizedDescription)")
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        isBackgroundRefreshing = false
    }
    
    private func calculateCoverSize(for geometry: GeometryProxy) -> (width: CGFloat, height: CGFloat) {
        let spacing: CGFloat = 16 // Grid间距
        let horizontalPadding: CGFloat = 16 // 水平边距
        let columns: CGFloat = 3 // 列数
        
        // 计算用宽度
        let availableWidth = geometry.size.width - (horizontalPadding * 2) - (spacing * (columns - 1))
        // 计算单个封面宽度
        let coverWidth = (availableWidth / columns).rounded(.down)
        // 使用 3:4 的宽高比计算高度
        let coverHeight = (coverWidth * 4 / 3).rounded(.down)
        
        return (coverWidth, coverHeight)
    }
    
    private func loadBookCover(for book: Book, in geometry: GeometryProxy) -> some View {
        let coverSize = calculateCoverSize(for: geometry)
        
        return Group {
            if let cachedImage = libraryManager.getCoverImage(for: book.id) {
                cachedImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: coverSize.width, height: coverSize.height)
                    .clipped()
                    .onAppear {
                        Task { @MainActor in
                            if let uiImage = await ImageUtils.convertToUIImage(from: cachedImage) {
                                print("BookLibrariesView - 加载缓存封面大小: \(uiImage.size), 内存占用: \(ImageUtils.imageSizeInBytes(uiImage)) bytes")
                            }
                        }
                    }
            } else {
                AsyncImage(url: URL(string: book.coverURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: coverSize.width, height: coverSize.height)
                            .clipped()
                            .onAppear {
                                libraryManager.updateBookCover(book.id, image: image)
                                downloadingCovers.remove(book.id)
                            }
                    case .failure(_):
                        ZStack {
                            Color.gray.opacity(0.1)
                            Image(systemName: "book.fill")
                                .font(.system(size: coverSize.width * 0.25))
                                .foregroundColor(.gray)
                                .onAppear {
                                    if !downloadingCovers.contains(book.id) {
                                        retryDownloadCover(for: book)
                                    }
                                }
                        }
                        .frame(width: coverSize.width, height: coverSize.height)
                    case .empty:
                        ZStack {
                            Color.gray.opacity(0.1)
                            ProgressView()
                                .scaleEffect(1.2)
                        }
                        .frame(width: coverSize.width, height: coverSize.height)
                    @unknown default:
                        Color.gray.opacity(0.1)
                            .frame(width: coverSize.width, height: coverSize.height)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func retryDownloadCover(for book: Book) {
        guard !downloadingCovers.contains(book.id) else { return }
        
        downloadingCovers.insert(book.id)
        
        Task {
            do {
                guard let url = URL(string: book.coverURL) else {
                    downloadingCovers.remove(book.id)
                    return
                }
                
                let (data, _) = try await URLSession.shared.data(from: url)
                
                guard let uiImage = UIImage(data: data) else {
                    await MainActor.run { downloadingCovers.remove(book.id) }
                    return
                }
                
                await MainActor.run {
                    let image = Image(uiImage: uiImage)
                    libraryManager.updateBookCover(book.id, image: image)
                    downloadingCovers.remove(book.id)
                }
            } catch {
                print("重试下载封面失败: \(error.localizedDescription)")
                await MainActor.run {
                    downloadingCovers.remove(book.id)
                }
            }
        }
    }
    
    private func refreshBooks() async {
        await viewModel.refreshBooksOnRelease(updateCovers: false)
    }
    
    private func forceRefreshBooks() async {
        await viewModel.refreshBooksOnRelease(updateCovers: true)
    }
    
    private func openBook(_ book: Book) async {
        // Check if chapters are loaded
        if book.chapters.isEmpty {
            await MainActor.run {
                loadingChapterBookId = book.id
                isLoadingChapters = true
            }
            
            do {
                // Load chapters using your existing chapter loading logic
                if let updatedBook = try await viewModel.loadChapters(for: book) {
                    await MainActor.run {
                        selectedBook = updatedBook
                        isShowingBookReader = true
                        loadingChapterBookId = nil
                        isLoadingChapters = false
                    }
                }
            } catch {
                print("Failed to load chapters: \(error)")
                await MainActor.run {
                    loadingChapterBookId = nil
                    isLoadingChapters = false
                    // You might want to show an error alert here
                }
            }
        } else {
            await MainActor.run {
                selectedBook = book
                isShowingBookReader = true
            }
        }
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                GeometryReader { geometry in
                    ZStack {
                        ScrollView {
                            let _ = print("当前书籍数量: \(viewModel.books.count)")
                            
                            RefreshControl(
                                coordinateSpace: .named("RefreshControl"),
                                onRefresh: {
                                    Task { @MainActor in
                                        await refreshBooks()
                                        
                                        withAnimation(.spring()) {
                                            HapticManager.shared.successFeedback()
                                            viewModel.isLoading = true
                                            viewModel.loadingMessage = "刷新完成"
                                            viewModel.isRefreshCompleted = true
                                            viewModel.loadedBooksCount = viewModel.totalBooksCount
                                        }
                                        
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        
                                        withAnimation {
                                            viewModel.isLoading = false
                                            viewModel.isRefreshCompleted = false
                                        }
                                    }
                                },
                                isPulling: $isPulling,
                                pullProgress: $pullProgress
                            )
                            
                            if viewModel.books.isEmpty {
                                EmptyLibraryView(selectedTab: $selectedTab)
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 16),
                                    GridItem(.flexible(), spacing: 16),
                                    GridItem(.flexible(), spacing: 16)
                                ], spacing: 16) {
                                    ForEach(viewModel.books) { book in
                                        VStack(alignment: .leading, spacing: 8) {
                                            ZStack(alignment: .topTrailing) {
                                                loadBookCover(for: book, in: geometry)
                                                    .modifier(BookOpeningEffect(
                                                        isSelected: selectedBookForAnimation?.id == book.id,
                                                        onComplete: {
                                                            if isLoadingChapters { return }
                                                            Task {
                                                                await openBook(book)
                                                            }
                                                        }
                                                    ))
                                                    .overlay(
                                                        Group {
                                                            if loadingChapterBookId == book.id {
                                                                ProgressView()
                                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                                    .padding(8)
                                                                    .background(.ultraThinMaterial)
                                                                    .cornerRadius(8)
                                                            }
                                                        }
                                                    )
                                                
                                                if booksWithUpdates.contains(book.id) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(Color.red)
                                                            .frame(width: 20, height: 20)
                                                        Text("新")
                                                            .font(.system(size: 10))
                                                            .foregroundColor(.white)
                                                            .bold()
                                                    }
                                                    .offset(x: 10, y: -10)
                                                    .transition(.scale.combined(with: .opacity))
                                                }
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(book.title)
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                                    .foregroundColor(.primary)
                                                
                                                Text(book.author)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .scaleEffect(pressedBookId == book.id ? 0.9 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressedBookId)
                                        .onTapGesture {
                                            HapticManager.shared.impactFeedback(style: .light)
                                            selectedBookForAnimation = book
                                        }
                                        .onChange(of: selectedBookForAnimation) { book in
                                            if let book = book, isAnimating {
                                                selectedBook = book
                                                isShowingBookReader = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                                    selectedBookForAnimation = nil
                                                    isAnimating = false
                                                }
                                            }
                                        }
                                        .onChange(of: isShowingBookReader) { isShowing in
                                            if !isShowing {
                                                selectedBookForAnimation = nil
                                                isAnimating = false
                                            }
                                        }
                                        .onLongPressGesture(minimumDuration: 0.3, pressing: { isPressing in
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                pressedBookId = isPressing ? book.id : nil
                                            }
                                            if isPressing {
                                                HapticManager.shared.impactFeedback(style: .soft)
                                            }
                                        }) {
                                            HapticManager.shared.impactFeedback(style: .medium)
                                            selectedBookForMenu = book
                                            showActionMenu = true
                                            
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                pressedBookId = nil
                                            }
                                        }
                                        .onChange(of: selectedBook) { newBook in
                                            if let newBook = newBook {
                                                withAnimation {
                                                    booksWithUpdates.remove(newBook.id)
                                                    libraryManager.saveUpdateStatus(for: newBook.id, hasUpdate: false)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                            }
                        }
                        .coordinateSpace(name: "RefreshControl")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        if viewModel.isLoading {
                            VStack {
                                UpdateProgressToast(
                                    progress: Double(viewModel.loadedBooksCount) / Double(viewModel.totalBooksCount),
                                    message: viewModel.loadingMessage
                                )
                                .padding(.top, 8)
                                Spacer()
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
                .navigationTitle("书架")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                                .rotationEffect(.degrees(isPulling ? 180 : 0))
                                .animation(.easeInOut(duration: 0.3), value: isPulling)
                            
                            Text(viewModel.lastUpdateTimeString.isEmpty ? 
                                "下拉刷新" : 
                                viewModel.lastUpdateTimeString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.gray.opacity(0.1))
                        )
                        .opacity(0.9)
                    }
                }
            }
            
            if showActionMenu, let book = selectedBookForMenu {
                ElegantActionMenu(
                    book: book,
                    bookCover: libraryManager.getCoverImage(for: book.id),
                    onInfo: {
                        showActionMenu = false
                        showingBookInfo = true
                    },
                    onRefresh: {
                        Task {
                            await viewModel.refreshSingleBook(book)
                        }
                        showActionMenu = false
                    },
                    onDelete: {
                        bookToRemove = book
                        showingCustomRemoveAlert = true
                        showActionMenu = false
                    },
                    isPresented: $showActionMenu
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(), value: showActionMenu)
        .animation(.spring(), value: viewModel.isLoading)
        .animation(.spring(), value: viewModel.isRefreshCompleted)
        .environmentObject(viewModel)
        .onAppear {
            print("BookLibrariesView appeared")
            viewModel.setLibraryManager(libraryManager)
            viewModel.loadBooks()
            
            startAutoUpdateCheck()
            
            Task {
                await checkUpdatesInBackground()
            }
        }
        .onDisappear {
            updateCheckTimer?.invalidate()
            updateCheckTimer = nil
        }
        .onChange(of: autoCheckUpdate) { newValue in
            if newValue {
                startAutoUpdateCheck()
            } else {
                updateCheckTimer?.invalidate()
                updateCheckTimer = nil
            }
        }
        .onChange(of: checkUpdateInterval) { _ in
            if autoCheckUpdate {
                startAutoUpdateCheck()
            }
        }
        .overlay {
            if showingCustomRemoveAlert, let book = bookToRemove {
                CustomRemoveBookAlert(
                    book: book,
                    isPresented: $showingCustomRemoveAlert,
                    onConfirm: {
                        viewModel.removeBook(book)
                        bookToRemove = nil
                    },
                    onCancel: {
                        bookToRemove = nil
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .sheet(isPresented: $showingBookInfo) {
            if let book = selectedBookForMenu {
                BookInfoView(book: book)
            }
        }
    }
    
    private func startAutoUpdateCheck() {
        updateCheckTimer?.invalidate()
        
        if autoCheckUpdate {
            updateCheckTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(checkUpdateInterval * 60), repeats: true) { _ in
                Task {
                    await checkUpdatesInBackground()
                }
            }
        }
    }
}

struct ElegantLoadingView: View {
    let message: String
    let progress: Double
    let totalBooks: Int
    let currentBookName: String
    let isCompleted: Bool
    let lastUpdateTimeString: String
    
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("正在更新书架")
                .font(.headline)
                .foregroundColor(.primary)
            
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkOpacity)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            checkmarkScale = 1.0
                            checkmarkOpacity = 1
                        }
                    }
                Text("更新完成")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .transition(.opacity)
                
                Text(lastUpdateTimeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                Text(currentBookName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 50)
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(self.progress, 1.0)))
                        .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .foregroundColor(Color.blue)
                        .rotationEffect(Angle(degrees: 270.0))
                        .animation(.linear, value: progress)
                        .frame(width: 100, height: 100)

                    VStack(spacing: 5) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("\(Int(progress * Double(totalBooks)))/\(totalBooks)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 250)
        .padding(25)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .transition(.opacity)
        .animation(.easeInOut, value: isCompleted)
    }
}


struct ElegantErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(30)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .transition(.opacity)
    }
}

struct RefreshControl: View {
    var coordinateSpace: CoordinateSpace
    var onRefresh: () -> Void
    @Binding var isPulling: Bool
    @Binding var pullProgress: CGFloat
    
    let threshold: CGFloat = 50
    @State private var refreshTriggered = false
    
    var body: some View {
        GeometryReader { geo in
            let y = geo.frame(in: coordinateSpace).minY
            let progress = min(max(0, y / threshold), 1)
            
            ZStack(alignment: .center) {
                ProgressView()
                    .scaleEffect(progress)
                    .opacity(progress)
            }
            .frame(width: geo.size.width, height: threshold)
            .offset(y: -threshold + (progress * threshold))
            .onChange(of: y) { newValue in
                pullProgress = progress
                
                if newValue > 0 {
                    isPulling = true
                    
                    if y >= threshold && !refreshTriggered {
                        refreshTriggered = true
                        onRefresh()
                    }
                } else {
                    isPulling = false
                    refreshTriggered = false
                }
            }
        }
        .frame(height: 0)
    }
}

struct ElegantActionMenu: View {
    let book: Book
    let bookCover: Image?
    var onInfo: () -> Void
    var onRefresh: () -> Void
    var onDelete: () -> Void
    @Binding var isPresented: Bool
    @EnvironmentObject private var viewModel: BookLibrariesViewModel
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        if let bookCover = bookCover {
                            bookCover
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .shadow(radius: 2)
                        } else {
                            Color.gray.opacity(0.2)
                                .frame(width: 60, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.headline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundColor(.primary)
                            Text(book.author)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.systemBackground))
                    
                    VStack(spacing: 0) {
                        MenuButton(
                            title: "书籍信息",
                            icon: "info.circle.fill",
                            color: .blue,
                            action: onInfo
                        )
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        MenuButton(
                            title: "更新目录",
                            icon: "arrow.triangle.2.circlepath",
                            color: .green,
                            action: {
                                Task {
                                    await viewModel.refreshSingleBook(book)
                                }
                                isPresented = false
                            }
                        )
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        MenuButton(
                            title: "从书架移除",
                            icon: "trash.fill",
                            color: .red,
                            action: onDelete
                        )
                    }
                    .background(Color(UIColor.systemBackground))
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        Text("取消")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .background(Color(UIColor.systemBackground))
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                    )
                
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }
}

struct ElegantProgressIndicator: View {
    let message: String
    let progress: Double
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 24))
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                }
            }
            
            Text(message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct UpdateProgressToast: View {
    let progress: Double
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if message.contains("完成") {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 20, height: 20)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(-90))
                }
            }
            
            Text(message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

struct BookLibrariesView_Previews: PreviewProvider {
    static var previews: some View {
        BookLibrariesView(
            selectedBook: .constant(nil),
            isShowingBookReader: .constant(false),
            selectedTab: .constant(0)
        )
    }
}

struct BookOpeningEffect: ViewModifier {
    let isSelected: Bool
    let onComplete: () -> Void
    
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 1
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(rotationAngle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.3
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: isSelected) { newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        rotationAngle = -45
                        scale = 1.1
                        opacity = 0.7
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        onComplete()
                    }
                } else {
                    rotationAngle = 0
                    scale = 1
                    opacity = 1
                }
            }
    }
}

struct CustomRemoveBookAlert: View {
    let book: Book
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                        onCancel()
                    }
                }
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                    .padding(.top, 25)
                
                Text("确认删除")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                VStack(spacing: 8) {
                    Text("《\(book.title)》")
                        .font(.system(size: 17, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Text("此操作将从书架中移除该书，且不可恢复。")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 15) {
                    Button {
                        withAnimation {
                            isPresented = false
                            onCancel()
                        }
                    } label: {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                    }
                    
                    Button {
                        withAnimation {
                            isPresented = false
                            onConfirm()
                        }
                    } label: {
                        Text("删除")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 25)
            }
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground))
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
    }
}

struct EmptyLibraryView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "books.vertical")
                .font(.system(size: 70))
                .foregroundColor(.gray)
                .padding(.bottom, 10)
            
            Text("书架空空如也")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("去书城发现好书，开始阅读之旅吧")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                selectedTab = 1
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("去书城看看")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 25)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
