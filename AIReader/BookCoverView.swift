import SwiftUI

struct BookCoverView: View {
    let book: Book
    @StateObject private var imageLoader = ImageLoader()
    @EnvironmentObject private var viewModel: BookLibrariesViewModel
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            ZStack(alignment: .bottom) {
                // Check if this is a local book with default cover
                if book.coverURL == "file://local/default_cover" {
                    // Display default cover for local books
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 90, height: 135)
                            .cornerRadius(8)
                        
                        VStack(spacing: 5) {
                            Image(systemName: "book.closed.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .foregroundColor(.gray)
                            
                            Text("本地文件")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                } else if let image = imageLoader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 135)
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 90, height: 135)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                        )
                }
                
                // 修改进度条显示逻辑
                if viewModel.isDownloading && viewModel.downloadingBookName == book.title && !viewModel.isBookDownloaded(book) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * CGFloat(viewModel.downloadProgress))
                        }
                    }
                    .frame(width: 90, height: 8)
                    .cornerRadius(4)
                    .padding(.bottom, 2)
                }
            }
            
            VStack(spacing: 0) {
                Text(book.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 90, height: 36)
                
                Text(book.author)
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, -5)
            }
            .frame(width: 90)
            .padding(.top, 0)
        }
        .frame(width: 100, height: 190)
        .onAppear {
            // Only try to load remote images, not for local books
            if book.coverURL != "file://local/default_cover" {
                imageLoader.loadImage(from: book.coverURL)
            }
        }
    }
}

struct BookCoverView_Previews: PreviewProvider {
    static var previews: some View {
        BookCoverView(book: Book(
            title: "A Very Long Book Title That Might Wrap",
            author: "Author Name",
            coverURL: "",
            lastUpdated: "",
            status: "",
            introduction: "",
            chapters: [],
            link: ""
        ))
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
