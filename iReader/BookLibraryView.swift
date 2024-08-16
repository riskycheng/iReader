import SwiftUI

struct BookLibraryView: View {
    let books: [Book]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(books, id: \.self) { book in
                    NavigationLink(destination: destinationView(for: book)) {
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
    
    // Helper function to provide the destination view
    private func destinationView(for book: Book) -> some View {
        if let firstChapterLink = book.chapters.first?.link {
            print("Navigating to: \(firstChapterLink)")
            return AnyView(ReadingView(book: book, chapterLink: firstChapterLink))
        } else {
            return AnyView(ReadingView(book: book, chapterLink: nil))
        }
    }
}
