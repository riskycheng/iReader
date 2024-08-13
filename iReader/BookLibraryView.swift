import SwiftUI

struct BookLibraryView: View {
    let books: [Book]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(books, id: \.self) { book in
                    NavigationLink(destination: ReadingView(book: book)) {
                        VStack {
                            Image(systemName: "book.fill") // Placeholder for book cover
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                            
                            Text(book.title)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding(.top, 5)
                            
                            Text(book.introduction)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
        .edgesIgnoringSafeArea(.top) // Align the content from the top left
    }
}
