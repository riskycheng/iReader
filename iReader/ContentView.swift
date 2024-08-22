import SwiftUI

struct ContentView: View {
    @State private var books: [Book] = []

    var body: some View {
        TabView {
            MainView(books: $books)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("主页")
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
