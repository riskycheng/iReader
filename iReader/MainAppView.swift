import SwiftUI

struct MainAppView: View {
    @State private var selectedTab = 0
    @State private var selectedBook: Book?
    @State private var isShowingBookReader = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BookLibrariesView(selectedBook: $selectedBook, isShowingBookReader: $isShowingBookReader)
                .tabItem {
                    Image(systemName: "books.vertical")
                    Text("书架")
                }
                .tag(0)
            
            BookStoreView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("书城")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "person")
                    Text("我")
                }
                .tag(2)
        }
        .onChange(of: selectedBook) { book in
            print("Selected book changed: \(book?.title ?? "nil")")
        }
        .onChange(of: isShowingBookReader) { isShowing in
            print("isShowingBookReader changed: \(isShowing)")
        }
        .fullScreenCover(isPresented: $isShowingBookReader, content: {
            if let book = selectedBook {
                BookReadingView(book: book, isPresented: $isShowingBookReader)
            } else {
                Text("No book selected")
            }
        })
    }
}
