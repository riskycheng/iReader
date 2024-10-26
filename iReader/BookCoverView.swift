import SwiftUI

struct BookCoverView: View {
    let book: Book
    @StateObject private var imageLoader = ImageLoader()
    @EnvironmentObject private var viewModel: BookLibrariesViewModel
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            ZStack(alignment: .bottom) {
                if let image = imageLoader.image {
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
                
                // 改进的下载进度条
                if viewModel.isDownloading && viewModel.downloadingBookName == book.title {
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
                    .multilineTextAlignment(.center)
                    .frame(height: 36)
                
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
            imageLoader.loadImage(from: book.coverURL)
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
