import SwiftUI

public struct LocalBookStoreView: View {
    @State private var showingHelpSheet = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 图标
            Image(systemName: "books.vertical")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
            
            // 标题
            Text("本地图书库")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 说明文字
            Text("您可以通过以下方式添加书籍：")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // 上传选项
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 15) {
                    Image(systemName: "wifi")
                        .frame(width: 30, height: 30)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("通过Wi-Fi上传")
                            .font(.headline)
                        Text("在同一网络下，通过浏览器访问")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                HStack(spacing: 15) {
                    Image(systemName: "folder")
                        .frame(width: 30, height: 30)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading) {
                        Text("从本地文件导入")
                            .font(.headline)
                        Text("从文件应用选择并导入电子书")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                HStack(spacing: 15) {
                    Image(systemName: "icloud.and.arrow.down")
                        .frame(width: 30, height: 30)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading) {
                        Text("从云端同步")
                            .font(.headline)
                        Text("从iCloud或其他云服务导入")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            // 帮助按钮
            Button(action: {
                showingHelpSheet = true
            }) {
                Text("查看详细说明")
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
        .navigationTitle("本地图书库")
        .sheet(isPresented: $showingHelpSheet) {
            HelpSheetView()
        }
    }
}

struct HelpSheetView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("如何添加书籍")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("通过Wi-Fi上传")
                                .font(.headline)
                            
                            Text("1. 确保您的设备与电脑连接到同一Wi-Fi网络")
                            Text("2. 在应用设置中启用Wi-Fi传输功能")
                            Text("3. 在电脑浏览器中访问显示的IP地址")
                            Text("4. 将电子书文件拖放到浏览器窗口中")
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("从本地文件导入")
                                .font(.headline)
                            
                            Text("1. 点击\"从本地文件导入\"按钮")
                            Text("2. 在文件应用中选择您想要导入的电子书")
                            Text("3. 选择\"复制到iReader\"选项")
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("从云端同步")
                                .font(.headline)
                            
                            Text("1. 确保您已登录iCloud或其他云服务")
                            Text("2. 点击\"从云端同步\"按钮")
                            Text("3. 选择您想要导入的电子书文件")
                        }
                    }
                    .padding(.horizontal)
                    
                    Group {
                        Divider()
                        
                        Text("支持的文件格式")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("• EPUB (.epub)")
                            Text("• PDF (.pdf)")
                            Text("• TXT (.txt)")
                            Text("• MOBI (.mobi)")
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("使用帮助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LocalBookStoreView_Previews: PreviewProvider {
    static var previews: some View {
        LocalBookStoreView()
    }
}
