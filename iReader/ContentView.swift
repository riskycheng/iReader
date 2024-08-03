import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MainView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            Text("Page 2")
                .tabItem {
                    Image(systemName: "doc.fill")
                    Text("Documents")
                }
            
            Text("Page 3")
                .tabItem {
                    Image(systemName: "cloud.fill")
                    Text("Cloud")
                }
            
            Text("Page 4")
                .tabItem {
                    Image(systemName: "line.horizontal.3")
                    Text("More")
                }
        }
    }
}

struct MainView: View {
    var body: some View {
        VStack {
            // Logo and Search Bar
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Text("Quark")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.top, 50)
                
                HStack {
                    TextField("Search...", text: .constant(""))
                        .padding()
                        .cornerRadius(10)
                    
                    HStack {
                        Image(systemName: "mic.fill")
                            .padding(.trailing, 10)
                        
                        Image(systemName: "camera.fill")
                            .padding(.trailing, 10)
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Icon Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                ForEach(iconItems, id: \.self) { item in
                    VStack {
                        Image(systemName: item.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(item.color)
                        
                        Text(item.title)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding()
            
            Spacer()
        }
    }
}

struct IconItem: Hashable {
    let iconName: String
    let title: String
    let color: Color
}

let iconItems = [
    IconItem(iconName: "newspaper.fill", title: "Quark日报", color: .red),
    IconItem(iconName: "folder.fill", title: "Quark网盘", color: .blue),
    IconItem(iconName: "scanner.fill", title: "Quark扫描王", color: .purple),
    IconItem(iconName: "book.fill", title: "Quark学习", color: .orange),
    IconItem(iconName: "ellipsis.circle.fill", title: "更多", color: .gray),
    IconItem(iconName: "flame.fill", title: "Quark热搜", color: .red),
    IconItem(iconName: "checkmark.circle.fill", title: "Quark高考", color: .blue),
    IconItem(iconName: "cart.fill", title: "省钱集市", color: .pink),
    IconItem(iconName: "leaf.fill", title: "芭芭农场", color: .green),
    IconItem(iconName: "doc.fill", title: "Quark文档", color: .yellow)
]

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
