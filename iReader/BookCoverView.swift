import SwiftUI

struct BookCoverView: View {
    let book: Book
    @StateObject private var imageLoader = ImageLoader()
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) { // Removed spacing between VStack elements
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
            
            VStack(spacing: 0) { // Reduced spacing between title and author
                Text(book.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(height: 36) // Slightly reduced height
                
                Text(book.author)
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, -5)
            }
            .frame(width: 90)
            .padding(.top, 0) // Added a small padding at the top of the text block
        }
        .frame(width: 100, height: 190) // Slightly reduced overall height
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
