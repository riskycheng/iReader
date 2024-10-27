import SwiftUI

struct BookSearchResultView: View {
    let book: Book
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    
    var body: some View {
        NavigationLink(destination: BookInfoView(book: book)
            .onAppear {
                settingsViewModel.addBrowsingRecord(book)
            }
        ) {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Cover image region
                        AsyncImage(url: URL(string: book.coverURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 80, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.leading, 16)
                        
                        // Text stack region
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            Text(book.author)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Spacer(minLength: 4)
                            
                            Text(cleanIntroduction(book.introduction))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            Spacer(minLength: 4)
                            
                            Text("查看全部 >")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .frame(height: 120)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                    .frame(height: 120)
                }
                .frame(height: 120)
                .padding(.vertical, 12)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.horizontal, 16)
            }
        }
    }
    
    private func cleanIntroduction(_ text: String) -> String {
        let withoutNewlinesAndTabs = text.replacingOccurrences(of: "[\r\n\t]", with: " ", options: .regularExpression)
        let components = withoutNewlinesAndTabs.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct BookSearchResultList: View {
    let books: [Book]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(books) { book in
                    BookSearchResultView(book: book)
                }
            }
        }
    }
}

// Preview provider remains the same


struct BookSearchResultView_Previews: PreviewProvider {
    static var previews: some View {
        BookSearchResultList(books: [
            Book(
                id: UUID(),
                title: "大明：不一样的大明帝国",
                author: "番昌宏",
                coverURL: "https://example.com/book-cover.jpg",
                lastUpdated: "2023-04-01",
                status: "连载中",
                introduction: "被命运推入明朝的你，面临刀锋与理想的选择。拒绝权势，坚持自我，你的故事犹如一面镜子，映射着大明帝国的兴衰。在这个波澜壮阔的时代，每一个选择都可能改变历史的走向。",
                chapters: [],
                link: "https://example.com/book-link"
            ),
            Book(
                id: UUID(),
                title: "Another Book",
                author: "Another Author",
                coverURL: "https://example.com/another-cover.jpg",
                lastUpdated: "2023-04-02",
                status: "完结",
                introduction: "This is another book's introduction. It's a bit shorter to show how the view adapts to different content lengths. This is the great book I like to recommend to all of your friends!",
                chapters: [],
                link: "https://example.com/another-book-link"
            )
        ])
        .previewLayout(.sizeThatFits)
    }
}
