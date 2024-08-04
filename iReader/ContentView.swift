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
            
            Text("Page 3")
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
        IconItem(iconName: "newspaper.fill", title: "百度书城", color: .red),
        IconItem(iconName: "folder.fill", title: "七猫读书", color: .blue),
        IconItem(iconName: "scanner.fill", title: "番茄读书", color: .purple),
        IconItem(iconName: "book.fill", title: "微信读书", color: .orange),
        IconItem(iconName: "ellipsis.circle.fill", title: "更多", color: .gray)
    ]
    
    @State private var showAddIconDialog = false
    @State private var newIconName: String = ""
    @State private var newIconTitle: String = ""
    @State private var newIconColor: Color = .black
    
    var body: some View {
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
            AddIconView(iconItems: $iconItems, newIconName: $newIconName, newIconTitle: $newIconTitle, newIconColor: $newIconColor)
        }
    }
}

struct AddIconView: View {
    @Binding var iconItems: [IconItem]
    @Binding var newIconName: String
    @Binding var newIconTitle: String
    @Binding var newIconColor: Color
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Icon Name (SF Symbol)", text: $newIconName)
                TextField("Icon Title", text: $newIconTitle)
                ColorPicker("Icon Color", selection: $newIconColor)
            }
            .navigationBarTitle("Add New Icon", displayMode: .inline)
            .navigationBarItems(trailing: Button("Add") {
                let newItem = IconItem(iconName: newIconName, title: newIconTitle, color: newIconColor)
                iconItems.append(newItem)
                newIconName = ""
                newIconTitle = ""
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
