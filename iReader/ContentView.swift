import SwiftUI

struct ContentView: View {
    @State private var books: [Book] = []
    @State private var isReadingViewActive = false
    @State private var selectedBook: Book? = nil
    @State private var selectedChapterLink: String? = nil

    var body: some View {
        ZStack {
            if isReadingViewActive {
                // When ReadingView is active, the TabView is hidden
                if let book = selectedBook, let chapterLink = selectedChapterLink {
                    ReadingView(book: book, chapterLink: chapterLink, isReadingViewActive: $isReadingViewActive)
                        .transition(.move(edge: .bottom))
                        .edgesIgnoringSafeArea(.all) // Ensure full-screen mode
                }
            } else {
                // Show TabView when not in ReadingView
                TabView {
                    MainView(books: $books)
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("主页")
                        }
                    
                    BookLibraryView(books: books, onSelectBook: { book, chapterLink in
                        selectedBook = book
                        selectedChapterLink = chapterLink
                        isReadingViewActive = true
                    })
                    .tabItem {
                        Image(systemName: "books.vertical.fill")
                        Text("书架")
                    }
                    
                    Text("Page 4")
                        .tabItem {
                            Image(systemName: "line.horizontal.3")
                            Text("我的")
                        }
                }
            }
        }
    }
}
