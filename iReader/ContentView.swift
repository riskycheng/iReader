import SwiftUI

struct ContentView: View {
    @State private var books: [Book] = [
        Book(title: "Book 1", link: "https://www.bqgui.cc/book/4444/3.html", cover: "cover1", introduction: "Introduction for Book 1"),
        Book(title: "Book 2", link: "https://example.com/book2", cover: "cover2", introduction: "Introduction for Book 2"),
        // Add more books as needed
    ]
    
    var body: some View {
        TabView {
            MainView(books: $books)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("主页")
                }
            
            NavigationView {
                MultipleWindowsView(books: $books)
            }
            .tabItem {
                Image(systemName: "square.stack.3d.up.fill")
                Text("窗口")
            }
            
            NavigationView {
                BookLibraryView(books: books)
            }
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
