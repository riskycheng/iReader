import SwiftUI

struct BookInfoView: View {
    @StateObject private var viewModel: BookInfoViewModel
    @EnvironmentObject var libraryManager: LibraryManager
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingBookReader = false
    
    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookInfoViewModel(book: book))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Book cover
                AsyncImage(url: URL(string: viewModel.book.coverURL)) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 120, height: 180)
                .cornerRadius(8)
                
                // Book title and author
                VStack(spacing: 5) {
                    Text(viewModel.book.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(viewModel.book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Book details
                VStack(alignment: .leading, spacing: 10) {
                    Text("最后更新: \(viewModel.book.lastUpdated)")
                    Text("状态: \(viewModel.book.status)")
                    Text("简介: \(viewModel.book.introduction)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Chapter info
                VStack(alignment: .leading, spacing: 10) {
                    Text("目录")
                        .font(.headline)
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        ForEach(viewModel.book.chapters.prefix(5), id: \.title) { chapter in
                            Text(chapter.title)
                                .font(.subheadline)
                        }
                        if viewModel.book.chapters.count > 5 {
                            Text("...")
                                .font(.subheadline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 15) {
                    Button(action: {
                        isShowingBookReader = true
                    }) {
                        Text("开始阅读")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        viewModel.downloadBook()
                    }) {
                        Text(viewModel.isDownloading ? "下载中..." : "下载")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .disabled(viewModel.isDownloading)
                    
                    Button(action: {
                        viewModel.addToLibrary()
                    }) {
                        Text(viewModel.isAddedToLibrary ? "已在书架" : "加入书架")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .disabled(viewModel.isAddedToLibrary)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("书籍详情")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isShowingBookReader) {
            BookReadingView(book: viewModel.book, isPresented: $isShowingBookReader)
        }
        .onAppear {
            viewModel.fetchBookDetails()
        }
    }
}
