import SwiftUI

struct MainAppView: View {
    @State private var selectedTab = 0
        
        var body: some View {
            TabView(selection: $selectedTab) {
                
                BookLibrariesView()
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
        }
    }

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
    }
}
