import SwiftUI

// 确保 ChapterSelection 定义在全局作用域中
struct ChapterSelection: Identifiable {
    let id = UUID()
    let index: Int
}

struct BookInfoView: View {
    @StateObject private var viewModel: BookInfoViewModel
    @EnvironmentObject var libraryManager: LibraryManager
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingFullIntroduction = false
    @State private var isShowingFullChapterList = false
    @State private var selectedChapter: ChapterSelection? = nil // 用于记录所选章节索引
    @State private var startingChapterIndex: Int = 0 // 用于记录开始阅读的章节索引

    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookInfoViewModel(book: book))
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    bookCoverAndInfo
                    chapterList
                }
                .padding()
                .padding(.bottom, 100)
            }
            
            VStack {
                Spacer()
                floatingActionButtons
            }
            
            if viewModel.isLoading {
                loadingOverlay
            }
        }
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
        .alert(isPresented: $isShowingFullIntroduction) {
            Alert(
                title: Text(viewModel.book.title),
                message: Text(viewModel.book.introduction),
                dismissButton: .default(Text("关闭"))
            )
        }
        .onAppear {
            viewModel.fetchBookDetails()
            hideTabBar()
        }
        .onDisappear {
            showTabBar()
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("加载中...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !viewModel.currentChapterName.isEmpty {
                    Text(viewModel.currentChapterName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
    
    private var bookCoverAndInfo: some View {
        HStack(alignment: .top, spacing: 20) {
            AsyncImage(url: URL(string: viewModel.book.coverURL)) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(width: 120, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 5)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.book.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Text(viewModel.book.author)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(viewModel.book.introduction)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(6)
                    .padding(.top, 5)
                
                Button(action: {
                    isShowingFullIntroduction = true
                }) {
                    Text("查看完整简介")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.top, 5)
            }
            .frame(height: 180, alignment: .top)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var chapterList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("目录")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 5)
            
            if viewModel.isLoading {
                ProgressView()
            } else {
                ForEach(Array(viewModel.book.chapters.prefix(20).enumerated()), id: \.element.title) { index, chapter in
                    Button(action: {
                        // 设置所选章节
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(PlainButtonStyle()) // 去除默认按钮样式
                }
                
                if viewModel.book.chapters.count > 20 {
                    Button("查看完整目录") {
                        isShowingFullChapterList = true
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.top, 10)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var floatingActionButtons: some View {
        HStack(spacing: 15) {
            actionButton(
                title: viewModel.isDownloaded ? "已下载" : "下载",
                action: { viewModel.downloadBook() },
                isDisabled: viewModel.isDownloaded || viewModel.isDownloading,
                color: .blue
            )
            
            actionButton(
                title: "开始阅读",
                action: {
                    startingChapterIndex = determineStartingChapter()
                    selectedChapter = ChapterSelection(index: startingChapterIndex) // 设置所选章节以触发导航
                },
                isDisabled: false,
                color: .green
            )
            
            actionButton(
                title: viewModel.isAddedToLibrary ? "移出书架" : "加入书架",
                action: {
                    if viewModel.isAddedToLibrary {
                        viewModel.removeFromLibrary()
                    } else {
                        viewModel.addToLibrary()
                    }
                },
                isDisabled: false,
                color: .orange
            )
        }
        .frame(height: 50)
        .padding(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
        )
    }
    
    private func actionButton(title: String, action: @escaping () -> Void, isDisabled: Bool, color: Color) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(8)
        }
        .disabled(isDisabled)
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
    
    @State private var selectedChapter: ChapterSelection? = nil // 新增，用于记录所选章节索引
    @State private var isShowingBookReader = false      // 新增，控制阅读视图的显示
    
    var body: some View {
        NavigationView {
            List(Array(chapters.enumerated()), id: \.element.title) { index, chapter in
                Button(action: {
                    selectedChapter = ChapterSelection(index: index)   // 设置所选章节索引
                    isShowingBookReader = true     // 显示阅读视图
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
                .buttonStyle(PlainButtonStyle()) // 去除默认按钮样式
            }
            .navigationTitle("完整目录")
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
            .fullScreenCover(item: $selectedChapter, onDismiss: {
                selectedChapter = nil // 重置所选章节索引
            }) { chapterSelection in
                BookReadingView(book: book, isPresented: $isShowingBookReader, startingChapter: chapterSelection.index)
            }
        }
    }
}
