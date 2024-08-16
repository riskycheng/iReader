import SwiftUI

struct MainView: View {
    @Binding var books: [Book]
    
    @State private var iconItems: [IconItem] = [
        IconItem(iconName: "newspaper.fill", title: "笔趣阁", link: "https://www.zsdade.com/", color: .red),
        IconItem(iconName: "folder.fill", title: "七猫读书", link: "https://www.qimao.com", color: .blue),
        IconItem(iconName: "scanner.fill", title: "番茄读书", link: "https://www.tomato.com", color: .purple),
        IconItem(iconName: "book.fill", title: "微信读书", link: "https://www.wechat.com", color: .orange),
        IconItem(iconName: "ellipsis.circle.fill", title: "更多", link: "https://www.more.com", color: .gray)
    ]
    
    @State private var showAddIconDialog = false
    @State private var newIconName: String = ""
    @State private var newIconTitle: String = ""
    @State private var newIconLink: String = ""
    @State private var newIconColor: Color = .black
    
    var body: some View {
        NavigationView {
            VStack {
                // Logo and Search Bar
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        Text("iReader")
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
                        NavigationLink(destination: BookStoreWebViewContainer(books: $books, initialURL: URL(string: item.link)!)) {
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
                    Button(action: {
                        showAddIconDialog.toggle()
                    }) {
                        VStack {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                            
                            Text("Add")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding()
                
                Spacer()
            }
            .sheet(isPresented: $showAddIconDialog) {
                AddIconView(iconItems: $iconItems, newIconName: $newIconName, newIconTitle: $newIconTitle, newIconLink: $newIconLink, newIconColor: $newIconColor)
            }
        }
    }
}
