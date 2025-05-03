import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Network

class BookFileService: ObservableObject {
    static let shared = BookFileService()
    
    @Published var isWifiServerRunning = false
    @Published var serverURL: String = ""
    @Published var importedBooks: [URL] = []
    @Published var isImporting = false
    
    private var httpServer: HTTPServer?
    private let monitor = NWPathMonitor()
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let booksDirectory: URL
    
    private init() {
        // 创建书籍目录
        booksDirectory = documentsDirectory.appendingPathComponent("Books", isDirectory: true)
        
        do {
            if !FileManager.default.fileExists(atPath: booksDirectory.path) {
                try FileManager.default.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
            }
        } catch {
            print("创建书籍目录失败: \(error)")
        }
        
        // 设置网络监控
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied && self?.isWifiServerRunning == true {
                    self?.updateServerURL()
                } else {
                    self?.serverURL = ""
                }
            }
        }
        monitor.start(queue: DispatchQueue.global())
    }
    
    deinit {
        monitor.cancel()
        stopWifiServer()
    }
    
    // MARK: - Wi-Fi传输服务器
    
    func startWifiServer() {
        guard !isWifiServerRunning else { return }
        
        httpServer = HTTPServer()
        httpServer?.documentRoot = booksDirectory.path
        
        do {
            try httpServer?.start(port: 8080)
            isWifiServerRunning = true
            updateServerURL()
            
            print("Wi-Fi服务器已启动，端口: 8080")
        } catch {
            print("启动Wi-Fi服务器失败: \(error)")
            isWifiServerRunning = false
            serverURL = ""
        }
    }
    
    func stopWifiServer() {
        guard isWifiServerRunning, httpServer != nil else { return }
        
        httpServer?.stop()
        httpServer = nil
        isWifiServerRunning = false
        serverURL = ""
        
        print("Wi-Fi服务器已停止")
    }
    
    private func updateServerURL() {
        // 获取设备IP地址
        var ipAddress = "未知"
        
        if let wifiAddress = getWiFiAddress() {
            ipAddress = wifiAddress
        }
        
        serverURL = "http://\(ipAddress):8080"
    }
    
    private func getWiFiAddress() -> String? {
        var address: String?
        
        // 获取所有网络接口
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // 遍历网络接口
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            
            // 检查是否是活跃的接口（启用并运行）
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                // 检查是否是IPv4或IPv6地址
                if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                    // 转换为sockaddr_in或sockaddr_in6
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                   nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                        if let addressString = String(validatingUTF8: hostname), addressString.contains(".") {
                            address = addressString
                            break
                        }
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
    
    // MARK: - 本地文件导入
    
    func importLocalFiles() -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [.epub, .pdf, .text, .data]
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        documentPicker.allowsMultipleSelection = true
        
        return documentPicker
    }
    
    func processImportedFiles(urls: [URL]) {
        isImporting = true
        importedBooks.removeAll()
        
        for url in urls {
            do {
                // 创建目标URL
                let filename = url.lastPathComponent
                let destinationURL = booksDirectory.appendingPathComponent(filename)
                
                // 如果文件已存在，先删除
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // 复制文件
                try FileManager.default.copyItem(at: url, to: destinationURL)
                
                // 添加到导入列表
                importedBooks.append(destinationURL)
                print("成功导入文件: \(filename)")
                
            } catch {
                print("导入文件失败: \(error)")
            }
        }
        
        isImporting = false
        
        // 通知导入完成
        NotificationCenter.default.post(name: NSNotification.Name("BooksImported"), object: nil)
    }
    
    // MARK: - iCloud同步
    
    func importFromICloud() -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [.epub, .pdf, .text, .data]
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        documentPicker.allowsMultipleSelection = true
        
        return documentPicker
    }
    
    // MARK: - 获取所有书籍
    
    func getAllBooks() -> [URL] {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: booksDirectory, includingPropertiesForKeys: nil)
            return fileURLs
        } catch {
            print("获取书籍列表失败: \(error)")
            return []
        }
    }
    
    // MARK: - 解析书籍元数据
    
    func parseBookMetadata(url: URL) -> Book? {
        // 这里简单实现，实际应用中应该解析EPUB/PDF等格式的元数据
        let filename = url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()
        
        // 创建一个简单的Book对象
        let book = Book(
            id: UUID(),
            title: filename.replacingOccurrences(of: ".\(fileExtension)", with: ""),
            author: "未知作者",
            coverURL: "",
            lastUpdated: Date().formatted(date: .abbreviated, time: .omitted),
            status: "本地",
            introduction: "这是一本本地导入的书籍",
            chapters: [Book.Chapter(title: "第一章", link: url.absoluteString)],
            link: url.absoluteString,
            isDownloaded: true
        )
        
        return book
    }
}

// 简单的HTTP服务器实现
class HTTPServer {
    var documentRoot: String = ""
    private var serverSocket: Int32 = -1
    private var isRunning = false
    
    func start(port: UInt16) throws {
        // 创建socket
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw NSError(domain: "HTTPServerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建服务器socket"])
        }
        
        // 设置socket选项
        var value: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size))
        
        // 绑定地址
        var serverAddr = sockaddr_in()
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = port.bigEndian
        serverAddr.sin_addr.s_addr = INADDR_ANY.bigEndian
        
        let bindResult = withUnsafePointer(to: &serverAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult == 0 else {
            close(serverSocket)
            throw NSError(domain: "HTTPServerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法绑定服务器地址"])
        }
        
        // 监听连接
        guard listen(serverSocket, 5) == 0 else {
            close(serverSocket)
            throw NSError(domain: "HTTPServerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "无法监听连接"])
        }
        
        isRunning = true
        
        // 在后台线程接受连接
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            while self.isRunning {
                var clientAddr = sockaddr_in()
                var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                
                let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                        accept(self.serverSocket, sockaddrPtr, &clientAddrLen)
                    }
                }
                
                if clientSocket >= 0 {
                    // 处理客户端连接
                    DispatchQueue.global(qos: .background).async {
                        self.handleClient(clientSocket: clientSocket)
                    }
                }
            }
        }
    }
    
    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }
    
    private func handleClient(clientSocket: Int32) {
        // 简单的HTTP响应实现
        let response = """
        HTTP/1.1 200 OK
        Content-Type: text/html; charset=UTF-8
        
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>AIReader文件上传</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
                h1 { color: #333; }
                .upload-area { border: 2px dashed #ccc; padding: 20px; text-align: center; margin: 20px 0; border-radius: 5px; }
                .upload-area:hover { border-color: #007aff; }
                .file-list { margin-top: 20px; }
                .file-item { background: #f5f5f5; padding: 10px; margin-bottom: 10px; border-radius: 5px; }
                .btn { background: #007aff; color: white; border: none; padding: 10px 15px; border-radius: 5px; cursor: pointer; }
                .btn:hover { background: #0056b3; }
            </style>
        </head>
        <body>
            <h1>AIReader文件上传</h1>
            <p>将电子书文件拖放到下面的区域或点击选择文件</p>
            
            <div class="upload-area" id="dropArea">
                <p>拖放文件到这里</p>
                <input type="file" id="fileInput" multiple accept=".epub,.pdf,.txt,.mobi" style="display: none;">
                <button class="btn" onclick="document.getElementById('fileInput').click()">选择文件</button>
            </div>
            
            <div class="file-list" id="fileList"></div>
            
            <script>
                const dropArea = document.getElementById('dropArea');
                const fileInput = document.getElementById('fileInput');
                const fileList = document.getElementById('fileList');
                
                // 阻止默认拖放行为
                ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
                    dropArea.addEventListener(eventName, preventDefaults, false);
                    document.body.addEventListener(eventName, preventDefaults, false);
                });
                
                function preventDefaults(e) {
                    e.preventDefault();
                    e.stopPropagation();
                }
                
                // 高亮显示拖放区域
                ['dragenter', 'dragover'].forEach(eventName => {
                    dropArea.addEventListener(eventName, highlight, false);
                });
                
                ['dragleave', 'drop'].forEach(eventName => {
                    dropArea.addEventListener(eventName, unhighlight, false);
                });
                
                function highlight() {
                    dropArea.style.borderColor = '#007aff';
                    dropArea.style.backgroundColor = '#f0f8ff';
                }
                
                function unhighlight() {
                    dropArea.style.borderColor = '#ccc';
                    dropArea.style.backgroundColor = '';
                }
                
                // 处理拖放的文件
                dropArea.addEventListener('drop', handleDrop, false);
                fileInput.addEventListener('change', handleFiles, false);
                
                function handleDrop(e) {
                    const dt = e.dataTransfer;
                    const files = dt.files;
                    handleFiles({ target: { files } });
                }
                
                function handleFiles(e) {
                    const files = e.target.files;
                    for (let i = 0; i < files.length; i++) {
                        uploadFile(files[i]);
                    }
                }
                
                function uploadFile(file) {
                    const fileItem = document.createElement('div');
                    fileItem.className = 'file-item';
                    fileItem.innerHTML = `
                        <div>${file.name} (${formatFileSize(file.size)})</div>
                        <div class="progress" style="height: 5px; background: #eee; margin-top: 5px;">
                            <div class="progress-bar" style="height: 100%; width: 0%; background: #007aff;"></div>
                        </div>
                        <div class="status">准备上传...</div>
                    `;
                    fileList.appendChild(fileItem);
                    
                    const progressBar = fileItem.querySelector('.progress-bar');
                    const status = fileItem.querySelector('.status');
                    
                    const formData = new FormData();
                    formData.append('file', file);
                    
                    const xhr = new XMLHttpRequest();
                    xhr.open('POST', '/upload');
                    
                    xhr.upload.addEventListener('progress', e => {
                        if (e.lengthComputable) {
                            const percent = (e.loaded / e.total) * 100;
                            progressBar.style.width = percent + '%';
                            status.textContent = `上传中... ${Math.round(percent)}%`;
                        }
                    });
                    
                    xhr.addEventListener('load', () => {
                        if (xhr.status >= 200 && xhr.status < 300) {
                            status.textContent = '上传成功';
                            fileItem.style.borderLeft = '4px solid #4CAF50';
                        } else {
                            status.textContent = `上传失败: ${xhr.statusText}`;
                            fileItem.style.borderLeft = '4px solid #f44336';
                        }
                    });
                    
                    xhr.addEventListener('error', () => {
                        status.textContent = '上传失败: 网络错误';
                        fileItem.style.borderLeft = '4px solid #f44336';
                    });
                    
                    xhr.send(formData);
                }
                
                function formatFileSize(bytes) {
                    if (bytes === 0) return '0 Bytes';
                    const k = 1024;
                    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
                    const i = Math.floor(Math.log(bytes) / Math.log(k));
                    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
                }
            </script>
        </body>
        </html>
        """
        
        // 发送响应
        response.withCString { ptr in
            send(clientSocket, ptr, strlen(ptr), 0)
        }
        
        // 关闭客户端连接
        close(clientSocket)
    }
}

// 扩展UTType以支持更多文件类型
extension UTType {
    static var epub: UTType {
        UTType(importedAs: "org.idpf.epub-container")
    }
    
    static var mobi: UTType {
        UTType(importedAs: "com.amazon.mobi")
    }
}
