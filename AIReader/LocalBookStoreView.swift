import SwiftUI
import UniformTypeIdentifiers

// Import the required components
public struct LocalBookStoreView: View {
    @State private var showingHelpSheet = false
    @State private var showingWiFiTransfer = false
    @State private var showingDocumentPicker = false
    @State private var documentPickerType: DocumentPickerType = .local
    @State private var showingImportSuccess = false
    @State private var importedBookCount = 0
    
    enum DocumentPickerType {
        case local
        case iCloud
    }
    
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
                Button(action: {
                    showingWiFiTransfer = true
                }) {
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
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    documentPickerType = .local
                    showingDocumentPicker = true
                }) {
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
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    documentPickerType = .iCloud
                    showingDocumentPicker = true
                }) {
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
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
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
        .sheet(isPresented: $showingWiFiTransfer) {
            NavigationView {
                VStack(spacing: 25) {
                    // Status icon
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "wifi")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                    }
                    
                    // Status text
                    Text("服务器已启动")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    // Server address
                    VStack(spacing: 10) {
                        Text("在浏览器中访问以下地址：")
                            .font(.headline)
                        
                        HStack {
                            Text("http://192.168.1.100:8080")
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            Button(action: {
                                UIPasteboard.general.string = "http://192.168.1.100:8080"
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
                    
                    // Instructions
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
                    
                    // Control button
                    Button(action: {
                        // Start/stop server action would go here
                    }) {
                        Text("停止服务器")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
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
                            showingWiFiTransfer = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(isPresented: $showingDocumentPicker, onImport: { urls in
                // Process the imported files
                importedBookCount = urls.count
                showingImportSuccess = true
            })
        }
        .alert(isPresented: $showingImportSuccess) {
            Alert(
                title: Text("导入成功"),
                message: Text("已成功导入 \(importedBookCount) 本书籍"),
                dismissButton: .default(Text("确定"))
            )
        }
        .onAppear {
            // 监听书籍导入通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("BooksImported"),
                object: nil,
                queue: .main
            ) { _ in
                // 更新UI或执行其他操作
            }
        }
    }
}

// Document picker wrapper
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onImport: ([URL]) -> Void
    @ObservedObject private var libraryManager = LibraryManager.shared
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [UTType.epub, UTType.pdf, UTType.text, UTType.data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Process each selected file
            var importedBooks: [URL] = []
            
            for url in urls {
                do {
                    // Create a permanent copy in the app's Documents directory
                    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let booksDirectory = documentsDirectory.appendingPathComponent("Books", isDirectory: true)
                    
                    // Create the Books directory if it doesn't exist
                    if !FileManager.default.fileExists(atPath: booksDirectory.path) {
                        try FileManager.default.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
                    }
                    
                    // Create a unique filename to avoid conflicts
                    let uniqueFilename = "\(UUID().uuidString)_\(url.lastPathComponent)"
                    let destinationURL = booksDirectory.appendingPathComponent(uniqueFilename)
                    
                    print("Attempting to copy file from: \(url.path)")
                    print("To destination: \(destinationURL.path)")
                    
                    // Try to directly read the file data and write it to the new location
                    // This approach works even when security-scoped resource access fails
                    let fileData = try Data(contentsOf: url)
                    try fileData.write(to: destinationURL)
                    
                    print("Successfully copied \(fileData.count) bytes to permanent location")
                    
                    // Create a local book using the permanent path
                    let localBook = createLocalBook(from: destinationURL)
                    
                    // Add to library with default cover
                    parent.libraryManager.addBook(localBook, withCoverImage: Image(systemName: "book.closed"))
                    
                    importedBooks.append(destinationURL)
                    print("Added local book: \(localBook.title) from \(destinationURL.lastPathComponent)")
                } catch {
                    print("Error importing file: \(error)")
                }
            }
            
            // Call the onImport callback with the permanent URLs
            parent.onImport(importedBooks)
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
        
        // Create a Book object from a local file URL
        private func createLocalBook(from url: URL) -> Book {
            let filename = url.lastPathComponent
            let fileExtension = url.pathExtension.lowercased()
            
            // Store the absolute file path directly for file I/O operations
            let localFilePath = url.path
            print("Creating local book with file path: \(localFilePath)")
            
            // Create a single chapter with the entire content
            // IMPORTANT: Use the exact path without any additional prefixes
            let chapter = Book.Chapter(title: "全文", link: localFilePath)
            
            // Create a book with default metadata
            // Ensure we have at least one chapter to prevent index out of range errors
            let safeChapters = [chapter]
            
            print("Creating local book with chapter link: \(chapter.link)")
            
            return Book(
                id: UUID(), // Ensure we have a unique ID
                title: filename.replacingOccurrences(of: "."+fileExtension, with: ""),
                author: "本地导入",
                coverURL: "file://local/default_cover", // Special marker for local book default cover
                lastUpdated: getCurrentDate(),
                status: "本地文件",
                introduction: "本地导入的"+fileExtension.uppercased()+"文件",
                chapters: safeChapters,
                link: localFilePath, // Use direct path without any scheme
                bookmarks: [],
                isDownloaded: true // Mark as downloaded since it's local
            )
        }
        
        // Get current date formatted as string
        private func getCurrentDate() -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }
    }
}

// Extension for UTType
extension UTType {
    static var epub: UTType {
        UTType(importedAs: "org.idpf.epub-container")
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
