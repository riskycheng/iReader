import SwiftUI

// 确保 ChapterSelection 定义在全局作用域中
struct ChapterSelection: Identifiable {
    let id = UUID()
    let index: Int
}

struct BookInfoView: View {
    @StateObject private var viewModel: BookInfoViewModel
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingFullIntroduction = false
    @State private var isShowingFullChapterList = false
    @State private var selectedChapter: ChapterSelection? = nil // 用于记录所选章节索引
    @State private var startingChapterIndex: Int = 0 // 用于记录开始阅读的章节索引

    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookInfoViewModel(book: book))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 顶部小边距
            Color.clear.frame(height: 8)
            
            // 主要内容区域
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 12) {
                    bookCoverAndInfo()
                    
                    // 目录部分（包含浮动按钮）
                    ZStack(alignment: .bottomTrailing) {
                        chapterListSection()
                        floatingActionButton
                            .padding(.trailing, 32) // 增加右边距，确保在圆角内
                            .padding(.bottom, 24)   // 增加底部边距，确保在圆角内
                    }
                }
            }
            
            // 移除底部 Spacer，让内容自然延伸
        }
        .padding(.bottom, 4)
        .background(Color(.systemBackground))
        .navigationTitle("书籍详情")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingFullChapterList) {
            FullChapterListView(book: viewModel.book, chapters: viewModel.book.chapters)
        }
        .fullScreenCover(item: $selectedChapter) { chapterSelection in
            BookReadingView(
                book: viewModel.book,
                isPresented: Binding(
                    get: { self.selectedChapter != nil },
                    set: { newValue in
                        if !newValue {
                            self.selectedChapter = nil
                        }
                    }
                ),
                startingChapter: chapterSelection.index
            )
        }
        .sheet(isPresented: $isShowingFullIntroduction) {
            NavigationView {
                ScrollView {
                    Text(viewModel.book.introduction)
                        .font(.system(size: 16))
                        .lineSpacing(4)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle(viewModel.book.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("关闭") {
                            isShowingFullIntroduction = false
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchBookDetails()
            hideTabBar()
            settingsViewModel.addBrowsingRecord(viewModel.book)
        }
        .onDisappear {
            showTabBar()
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("正在下载书籍信息...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if !viewModel.currentChapterName.isEmpty {
                    Text("正在解析: \(viewModel.currentChapterName)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                Button(action: {
                    viewModel.cancelLoading()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("取消")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
                .padding(.top, 5)
            }
            .padding(30)
            .background(Color.black.opacity(0.7))
            .cornerRadius(15)
        }
    }
    
    private func bookCoverAndInfo() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 20) {
                AsyncImage(url: URL(string: viewModel.book.coverURL)) { phase in
                    switch phase {
                    case .empty:
                        // 加载中状态
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                            ProgressView() // 添加加载动画
                                .scaleEffect(1.2)
                                .tint(.gray)
                        }
                    case .success(let image):
                        // 加成功状态
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        // 加载失败状态
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        }
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(radius: 5)
                
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isLoading {
                        Group {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 22)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 18)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 80)
                        }
                    } else {
                        Text(viewModel.book.title)
                            .font(.system(size: 22, weight: .bold))
                        Text(viewModel.book.author)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.book.introduction)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .frame(maxHeight: 110)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            
                            if viewModel.book.introduction.count > 100 {
                                Button(action: {
                                    isShowingFullIntroduction = true
                                }) {
                                    Text("开全部")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    private func chapterListSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("目录")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.isLoading {
                        ForEach(0..<5, id: \.self) { index in
                            HStack {
                                Text("\(index + 1).")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .leading)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 16)
                            }
                            .padding(.vertical, 5)
                        }
                    } else {
                        ForEach(Array(viewModel.book.chapters.prefix(20).enumerated()), id: \.element.title) { index, chapter in
                            Button(action: {
                                selectedChapter = ChapterSelection(index: index)
                            }) {
                                HStack {
                                    Text("\(index + 1).")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .leading)
                                    Text(chapter.title)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if viewModel.book.chapters.count > 20 {
                            Button(action: {
                                isShowingFullChapterList = true
                            }) {
                                Text("查看完整目录")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
    
    private var floatingActionButton: some View {
        Button(action: {
            if viewModel.isAddedToLibrary {
                viewModel.removeFromLibrary()
            } else {
                viewModel.addToLibrary()
            }
        }) {
            VStack(spacing: 2) {
                Image(systemName: viewModel.isAddedToLibrary ? "bookmark.slash.fill" : "bookmark.fill")
                    .font(.system(size: 16))
                Text(viewModel.isAddedToLibrary ? "移出书架" : "加入书架")
                    .font(.system(size: 9))
            }
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .padding(6)
            .background(viewModel.isAddedToLibrary ? Color.red : Color.blue)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.2), radius: 3)
        }
    }
    
    private func determineStartingChapter() -> Int {
        // 检查是否有保存的阅读进度
        if let savedProgress = libraryManager.getReadingProgress(for: viewModel.book.id) {
            return savedProgress.chapterIndex
        }
        // 如果没有保存的进度，从第一章开始
        return 0
    }
    
    private func hideTabBar() {
        UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController?.tabBarController?.tabBar.isHidden = true
    }
    
    private func showTabBar() {
        UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController?.tabBarController?.tabBar.isHidden = false
    }
}

struct FullChapterListView: View {
    let book: Book
    let chapters: [Book.Chapter]
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedChapter: ChapterSelection? = nil
    
    var body: some View {
        NavigationView {
            List(Array(chapters.enumerated()), id: \.element.title) { index, chapter in
                Button(action: {
                    selectedChapter = ChapterSelection(index: index)
                }) {
                    HStack {
                        Text("\(index + 1).")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)
                        Text(chapter.title)
                            .font(.system(size: 16, weight: .regular))
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("完整目录")
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
            .fullScreenCover(item: $selectedChapter) { chapterSelection in
                BookReadingView(
                    book: book,
                    isPresented: Binding(
                        get: { selectedChapter != nil },
                        set: { if !$0 { selectedChapter = nil } }
                    ),
                    startingChapter: chapterSelection.index
                )
            }
        }
    }
}
