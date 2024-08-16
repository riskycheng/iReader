import SwiftUI

struct BookLibraryView: View {
    let books: [Book]
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(books, id: \.title) { book in
                    NavigationLink(destination: ReadingView(book: book)) {
                        VStack {
                            if let coverURL = URL(string: book.coverURL), !book.coverURL.isEmpty {
                                AsyncImage(url: coverURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 150)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(10)
                                } placeholder: {
                                    Image(systemName: "book.fill") // Placeholder for loading
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 150)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(10)
                                }
                            } else {
                                Image(systemName: "book.fill") // Fallback for missing cover
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 150)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            }
                            
                            Text(book.title)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding(.top, 5)
                                .lineLimit(2) // Limit the title to 2 lines to avoid overflowing
                            
                            Text(book.introduction)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2) // Limit the introduction to 2 lines to maintain consistent spacing
                                .padding(.top, 2)
                        }
                        .padding()
                        .background(Color.white) // Optional: Background for each item
                        .cornerRadius(10)
                        .shadow(radius: 3)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .edgesIgnoringSafeArea(.top) // Align the content from the top left
    }
}
