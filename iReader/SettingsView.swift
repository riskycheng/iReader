import SwiftUI
import Foundation

struct SettingsView: View {
    @AppStorage("autoPreload") private var autoPreload = true
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingAboutUs = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("阅读设置")) {
                    Toggle("自动预加载", isOn: $autoPreload)
                        .font(.body)
                    Text("在阅读过程中，自动预加载后续5个章节，优化阅读体验")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    NavigationLink(destination: ReadingHistoryView(viewModel: viewModel)) {
                        Text("阅读记录")
                    }
                    
                    NavigationLink(destination: BrowsingHistoryView(viewModel: viewModel)) {
                        Text("浏览记录")
                    }
                }
                
                Section {
                    Button("关于我们") {
                        showingAboutUs = true
                    }
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showingAboutUs) {
                AboutUsView()
            }
        }
    }
}

struct ReadingHistoryView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var selectedBook: Book?
    @State private var isShowingBookReader = false
    
    var body: some View {
        List {
            ForEach(viewModel.readingHistory) { record in
                ReadingHistoryItemView(record: record)
                    .onTapGesture {
                        selectedBook = record.book
                    }
            }
        }
        .navigationTitle("阅读记录")
        .onAppear {
            viewModel.refreshReadingHistory()
        }
        .sheet(item: $selectedBook) { book in
            if let progress = libraryManager.getReadingProgress(for: book.id) {
                BookReadingView(book: book, isPresented: $isShowingBookReader, startingChapter: progress.chapterIndex)
            } else {
                BookInfoView(book: book)
            }
        }
    }
}

struct ReadingHistoryItemView: View {
    let record: ReadingRecord
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: record.book.coverURL)) { image in
                image.resizable()
            } placeholder: {
                Color.gray
            }
            .frame(width: 50, height: 75)
            .cornerRadius(5)
            
            VStack(alignment: .leading) {
                Text(record.book.title)
                    .font(.headline)
                Text(record.book.author)
                    .font(.subheadline)
                Text("上次阅读: \(record.lastChapter)")
                    .font(.caption)
                Text("时间: \(record.lastReadTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BrowsingHistoryView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedBook: Book?
    @State private var isShowingBookReader = false
    
    var body: some View {
        List {
            ForEach(viewModel.browsingHistory) { record in
                BrowsingHistoryItemView(record: record)
                    .onTapGesture {
                        selectedBook = record.book
                    }
            }
        }
        .navigationTitle("浏览记录")
        .onAppear {
            viewModel.refreshBrowsingHistory()
        }
        .sheet(item: $selectedBook) { book in
            BookInfoView(book: book)
        }
    }
}

struct BrowsingHistoryItemView: View {
    let record: BrowsingRecord
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: record.book.coverURL)) { image in
                image.resizable()
            } placeholder: {
                Color.gray
            }
            .frame(width: 50, height: 75)
            .cornerRadius(5)
            
            VStack(alignment: .leading) {
                Text(record.book.title)
                    .font(.headline)
                Text(record.book.author)
                    .font(.subheadline)
                Text(record.browseTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

class SettingsViewModel: ObservableObject {
    @Published var readingHistory: [ReadingRecord] = []
    @Published var browsingHistory: [BrowsingRecord] = []
    
    init() {
        loadReadingHistory()
        loadBrowsingHistory()
    }
    
    func loadReadingHistory() {
        readingHistory = UserDefaults.standard.readingHistory()
    }
    
    func loadBrowsingHistory() {
        browsingHistory = UserDefaults.standard.browsingHistory()
    }
    
    func deleteReadingHistory(at offsets: IndexSet) {
        readingHistory.remove(atOffsets: offsets)
        UserDefaults.standard.saveReadingHistory(readingHistory)
    }
    
    func deleteBrowsingHistory(at offsets: IndexSet) {
        browsingHistory.remove(atOffsets: offsets)
        UserDefaults.standard.saveBrowsingHistory(browsingHistory)
    }
    
    func addBrowsingRecord(_ book: Book) {
        let record = BrowsingRecord(
            id: UUID(),
            book: book,
            browseTime: DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        )
        
        // 获取现有的浏览历史
        var browsingHistory = UserDefaults.standard.browsingHistory()
        
        // 如果已经存在这本书的记录，更新它
        if let index = browsingHistory.firstIndex(where: { $0.book.id == book.id }) {
            browsingHistory.remove(at: index)
        }
        
        // 添加新记录到列表开头
        browsingHistory.insert(record, at: 0)
        
        // 限制历史记录数量（例如，只保留最近的50条记录）
        if browsingHistory.count > 50 {
            browsingHistory = Array(browsingHistory.prefix(50))
        }
        
        // 保存更新后的浏览历史
        UserDefaults.standard.saveBrowsingHistory(browsingHistory)
        
        // 更新发布的属性
        self.browsingHistory = browsingHistory
    }
    
    func refreshBrowsingHistory() {
        browsingHistory = UserDefaults.standard.browsingHistory()
        print("Refreshed browsing history. Current count: \(browsingHistory.count)")
    }
    
    func refreshReadingHistory() {
        readingHistory = UserDefaults.standard.readingHistory()
    }
}

struct ReadingRecord: Codable, Identifiable {
    let id: UUID
    let book: Book
    let lastChapter: String
    let lastReadTime: String
}

struct BrowsingRecord: Codable, Identifiable {
    let id: UUID
    let book: Book
    let browseTime: String
}

struct AboutUsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                
                Text(Bundle.main.displayName ?? "妙笔阅读")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("版本: \(Bundle.main.appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("妙笔阅读是一款专注于提供优质阅读体验的应用。我们致力于为用户带来丰富的内容和便捷的阅读功能。")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 15) {
                    Button("隐私政策") {
                        showPrivacyPolicy = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("服务协议") {
                        showTermsOfService = true
                    }
                    .foregroundColor(.blue)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("关于我们", displayMode: .inline)
            .navigationBarItems(trailing: Button("关闭") {
                dismiss()
            })
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

extension UserDefaults {
    func readingHistory() -> [ReadingRecord] {
        guard let data = data(forKey: "readingHistory") else { return [] }
        return (try? JSONDecoder().decode([ReadingRecord].self, from: data)) ?? []
    }
    
    func saveReadingHistory(_ history: [ReadingRecord]) {
        let data = try? JSONEncoder().encode(history)
        set(data, forKey: "readingHistory")
    }
    
    func browsingHistory() -> [BrowsingRecord] {
        guard let data = data(forKey: "browsingHistory") else { return [] }
        return (try? JSONDecoder().decode([BrowsingRecord].self, from: data)) ?? []
    }
    
    func saveBrowsingHistory(_ history: [BrowsingRecord]) {
        let data = try? JSONEncoder().encode(history)
        set(data, forKey: "browsingHistory")
    }
}

extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String 
            ?? object(forInfoDictionaryKey: "CFBundleName") as? String
    }
    
    var appVersion: String {
        return "\(object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")(\(object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))"
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("隐私政策")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("最后更新日期：2024年3月20日")
                            .foregroundColor(.secondary)
                        
                        Text("信息收集与使用")
                            .font(.headline)
                        Text("我们仅收集必要的信息来提供更好的阅读体验，包括：\n• 阅读进度\n• 阅读偏好设置\n• 书籍收藏信息")
                        
                        Text("数据存储")
                            .font(.headline)
                        Text("所有数据均存储在您的设备本地，我们不会将其上传至服务器或与第三方共享。")
                        
                        Text("权限说明")
                            .font(.headline)
                        Text("本应用可能需要以下权限：\n• 网络访问：用于获取图书内容\n• 存储权限：用于缓存图书内容，提升阅读体验")
                    }
                }
                .padding()
            }
            .navigationBarTitle("隐私政策", displayMode: .inline)
            .navigationBarItems(trailing: Button("关闭") {
                dismiss()
            })
        }
    }
}

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("服务协议")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("最后更新日期：2024年3月20日")
                            .foregroundColor(.secondary)
                        
                        Text("服务说明")
                            .font(.headline)
                        Text("妙笔阅读为用户提供网络小说阅读服务。我们会持续更新内容源，确保为用户提供优质的阅读内容。")
                        
                        Text("用户行为规范")
                            .font(.headline)
                        Text("用户在使用本应用时，需遵守以下规范：\n• 遵守相关法律法规\n• 不得将本应用用于非法用途\n• 尊重知识产权")
                        
                        Text("免责声明")
                            .font(.headline)
                        Text("本应用提供的内容来自互联网，如有侵权请联系我们删除。我们不对内容的准确性、完整性承担责任。")
                    }
                }
                .padding()
            }
            .navigationBarTitle("服务协议", displayMode: .inline)
            .navigationBarItems(trailing: Button("关闭") {
                dismiss()
            })
        }
    }
}
