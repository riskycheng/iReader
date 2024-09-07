import SwiftUI

struct BookInfoView: View {
    let book: Book
    @State private var isShowingBookReader = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Book cover and title
                HStack {
                    Spacer()
                    VStack {
                        AsyncImage(url: URL(string: book.coverURL)) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 120, height: 180)
                        .cornerRadius(8)
                        
                        Text(book.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                
                // Author and genre
                Text("\(book.author) | \(book.status)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Chapter list
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("目录")
                            .font(.headline)
                        Spacer()
                        Text("查看目录 >")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    Text("共\(book.chapters.count)章 | \(book.lastUpdated)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(book.chapters.prefix(5), id: \.title) { chapter in
                        Text(chapter.title)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                
                // Action buttons
                HStack {
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
                        // Implement download functionality
                    }) {
                        Text("下载")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // Implement add to bookshelf functionality
                    }) {
                        Text("加入书架")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingBookReader) {
            BookReadingView(book: book, isPresented: $isShowingBookReader)
        }
    }
}
