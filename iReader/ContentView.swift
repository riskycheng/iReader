import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MainView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("主页")
                }
            
            NavigationView {
                MultipleWindowsView()
            }
            .tabItem {
                Image(systemName: "square.stack.3d.up.fill")
                Text("窗口")
            }
            
            NavigationView {
                BookLibraryView(books: [
                    Book(title: "Book 1", link: "https://www.bqgui.cc/book/4444/3.html", cover: "cover1", introduction: "Introduction for Book 1"),
                    Book(title: "Book 2", link: "https://example.com/book2", cover: "cover2", introduction: "Introduction for Book 2"),
                    // Add more books as needed
                ])
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

struct MainView: View {
    @State private var iconItems: [IconItem] = [
        IconItem(iconName: "newspaper.fill", title: "笔趣阁", link: "https://www.bqgui.cc", color: .red),
        IconItem(iconName: "folder.fill", title: "七猫读书", link: "https://www.qimao.com", color: .blue),
        IconItem(iconName: "scanner.fill", title: "番茄读书", link: "https://www.tomato.com", color: .purple),
        IconItem(iconName: "book.fill", title: "微信读书", link: "https://www.wechat.com", color: .orange),
        IconItem(iconName: "ellipsis.circle.fill", title: "更多", link: "https://www.more.com", color: .gray)
    ]
    
    @State private var showAddIconDialog = false
    @State private var newIconName: String = ""
    @State private var newIconTitle: String = ""
    @State private var newIconLink: String = "" // New state for the link
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
                        NavigationLink(destination: BookStoreWebViewContainer(initialURL: URL(string: item.link)!)) {
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


struct AddIconView: View {
    @Binding var iconItems: [IconItem]
    @Binding var newIconName: String
    @Binding var newIconTitle: String
    @Binding var newIconLink: String // New binding for the link
    @Binding var newIconColor: Color
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Icon Name (SF Symbol)", text: $newIconName)
                TextField("Icon Title", text: $newIconTitle)
                TextField("Icon Link", text: $newIconLink) // New text field for the link
                ColorPicker("Icon Color", selection: $newIconColor)
            }
            .navigationBarTitle("Add New Icon", displayMode: .inline)
            .navigationBarItems(trailing: Button("Add") {
                let newItem = IconItem(iconName: newIconName, title: newIconTitle, link: newIconLink, color: newIconColor)
                iconItems.append(newItem)
                newIconName = ""
                newIconTitle = ""
                newIconLink = "" // Reset the link
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
