import SwiftUI

struct BookInfoView: View {
    @StateObject private var viewModel: BookInfoViewModel
    @EnvironmentObject var libraryManager: LibraryManager
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingBookReader = false
    @State private var isIntroductionExpanded = false
    @State private var isShowingFullChapterList = false
    
    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookInfoViewModel(book: book))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                bookCoverAndInfo
                chapterList
                actionButtons
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("书籍详情")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingFullChapterList) {
            FullChapterListView(chapters: viewModel.book.chapters)
        }
        .fullScreenCover(isPresented: $isShowingBookReader) {
            BookReadingView(book: viewModel.book, isPresented: $isShowingBookReader)
        }
        .onAppear {
            viewModel.fetchBookDetails()
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
                infoRow(label: "最后更新", value: viewModel.book.lastUpdated)
                infoRow(label: "状态", value: viewModel.book.status)
                
                Text(viewModel.book.introduction)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(isIntroductionExpanded ? nil : 2)
                    .padding(.top, 5)
                
                Button(action: {
                    withAnimation {
                        isIntroductionExpanded.toggle()
                    }
                }) {
                    Text(isIntroductionExpanded ? "收起" : "展开")
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
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.primary)
        }
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
                ForEach(Array(viewModel.book.chapters.prefix(10).enumerated()), id: \.element.title) { index, chapter in
                    HStack {
                        Text("\(index + 1).")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)
                        Text(chapter.title)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("第\(index + 1)章")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                }
                
                if viewModel.book.chapters.count > 10 {
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
    
    private var actionButtons: some View {
        HStack(spacing: 15) {
            actionButton(
                title: viewModel.isDownloaded ? "已下载" : "下载",
                action: { viewModel.downloadBook() },
                isDisabled: viewModel.isDownloaded || viewModel.isDownloading,
                color: .blue
            )
            
            actionButton(
                title: "开始阅读",
                action: { isShowingBookReader = true },
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
}

struct FullChapterListView: View {
    let chapters: [Book.Chapter]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(Array(chapters.enumerated()), id: \.element.title) { index, chapter in
                HStack {
                    Text("\(index + 1).")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .leading)
                    Text(chapter.title)
                        .font(.system(size: 16, weight: .regular))
                    Spacer()
                    Text("第\(index + 1)章")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("完整目录")
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
