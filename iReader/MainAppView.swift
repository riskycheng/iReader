import SwiftUI

struct MainAppView: View {
    var body: some View {
        TabView {
            BookLibrariesView()
                .tabItem {
                    Image(systemName: "books.vertical")
                    Text("书架")
                }
            
            Text("排行榜")
                .tabItem {
                    Image(systemName: "list.number")
                    Text("排行榜")
                }
            
            Text("点滴")
                .tabItem {
                    Image(systemName: "drop")
                    Text("点滴")
                }
            
            Text("我的")
                .tabItem {
                    Image(systemName: "person")
                    Text("我的")
                }
        }
    }
}

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
    }
}
