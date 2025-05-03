import SwiftUI

struct WiFiTransferView: View {
    @ObservedObject var fileService = BookFileService.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                // 状态图标
                ZStack {
                    Circle()
                        .fill(fileService.isWifiServerRunning ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: fileService.isWifiServerRunning ? "wifi" : "wifi.slash")
                        .font(.system(size: 50))
                        .foregroundColor(fileService.isWifiServerRunning ? .green : .gray)
                }
                
                // 状态文本
                Text(fileService.isWifiServerRunning ? "服务器已启动" : "服务器未启动")
                    .font(.title2)
                    .fontWeight(.medium)
                
                // 服务器地址
                if fileService.isWifiServerRunning && !fileService.serverURL.isEmpty {
                    VStack(spacing: 10) {
                        Text("在浏览器中访问以下地址：")
                            .font(.headline)
                        
                        HStack {
                            Text(fileService.serverURL)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            Button(action: {
                                UIPasteboard.general.string = fileService.serverURL
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .padding(8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray5).opacity(0.5))
                    .cornerRadius(12)
                }
                
                // 使用说明
                VStack(alignment: .leading, spacing: 10) {
                    Text("使用说明：")
                        .font(.headline)
                    
                    Text("1. 确保您的电脑和设备连接到同一Wi-Fi网络")
                    Text("2. 在电脑浏览器中访问上面的地址")
                    Text("3. 将电子书文件拖放到浏览器窗口中")
                    Text("4. 上传完成后，文件将显示在您的书架中")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                // 控制按钮
                Button(action: {
                    if fileService.isWifiServerRunning {
                        fileService.stopWifiServer()
                    } else {
                        fileService.startWifiServer()
                    }
                }) {
                    Text(fileService.isWifiServerRunning ? "停止服务器" : "启动服务器")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(fileService.isWifiServerRunning ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding()
            .navigationTitle("Wi-Fi传输")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 如果服务器未运行，自动启动
                if !fileService.isWifiServerRunning {
                    fileService.startWifiServer()
                }
            }
            .onDisappear {
                // 离开视图时停止服务器
                if fileService.isWifiServerRunning {
                    fileService.stopWifiServer()
                }
            }
        }
    }
}
