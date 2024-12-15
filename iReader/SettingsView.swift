import SwiftUI
import Foundation

// 在文件顶部添加一个私有的扩展来定义共享的样式
private extension Font {
    static let selectorTitle = Font.body
    static let selectorValue = Font.system(.body, design: .rounded)
    static let selectorCaption = Font.caption
    static let optionText = Font.system(.subheadline, design: .rounded)
}

struct SettingsView: View {
    @AppStorage("autoPreload") private var autoPreload = true
    @AppStorage("preloadChaptersCount") private var preloadChaptersCount = 5
    @AppStorage("shouldShowGestureTutorial") private var shouldShowGestureTutorial = true
    @AppStorage("autoCheckUpdate") private var autoCheckUpdate = true
    @AppStorage("checkUpdateInterval") private var checkUpdateInterval = 30 // 默认30分钟检查一次
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingAboutUs = false
    @State private var showPreloadSettings = false
    
    var body: some View {
        NavigationView {
            List {
                // 阅读设置部分
                Section {
                    // 预加载开关
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("自动预加载")
                            .font(.body)
                        
                        Spacer()
                        
                        Toggle("", isOn: $autoPreload)
                            .labelsHidden()
                    }
                    
                    // 预加载章节数量选择器
                    if autoPreload {
                        PreloadChapterSelector(
                            preloadChaptersCount: $preloadChaptersCount,
                            autoPreload: $autoPreload
                        )
                    }
                    
                    // 阅读手势教程设置保持不变
                    HStack {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("阅读手势教程")
                                .font(.body)
                            
                            Text("打开书籍时显示操作提示")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $shouldShowGestureTutorial)
                            .labelsHidden()
                    }
                    
                    // 自动检查更新开关
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("自动检查更新")
                                .font(.body)
                            
                            Text("定期检查书籍更新")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $autoCheckUpdate)
                            .labelsHidden()
                    }
                    
                    // 检查更新间隔选择器
                    if autoCheckUpdate {
                        UpdateIntervalSelector(
                            checkUpdateInterval: $checkUpdateInterval,
                            autoCheckUpdate: $autoCheckUpdate
                        )
                    }
                } header: {
                    Text("阅读设置")
                }
                
                // 历史记录部分
                Section {
                    NavigationLink(destination: ReadingHistoryView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("阅读记录")
                                    .font(.body)
                                
                                Text("查看最近阅读的书籍")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: BrowsingHistoryView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("浏览记录")
                                    .font(.body)
                                
                                Text("查看最近浏览的书籍")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("历史记录")
                }
                
                // 关于部分
                Section {
                    Button(action: { showingAboutUs = true }) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("关于我们")
                                    .font(.body)
                                
                                Text("版本信息与法律声明")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .listStyle(InsetGroupedListStyle())
            .sheet(isPresented: $showingAboutUs) {
                ModernAboutUsView()
            }
        }
    }
}

// 现代化的关于我们视图
struct ModernAboutUsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // App Logo 和基本信息
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            if let image = UIImage(named: "AppLogo") {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(20)
                            }
                            
                            VStack(spacing: 8) {
                                Text(Bundle.main.displayName ?? "妙笔阅读")
                                    .font(.title2.weight(.semibold))
                                
                                Text("版本 \(Bundle.main.appVersion)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 20)
                }
                
                // 法律条款
                Section {
                    NavigationLink(destination: PrivacyPolicyView()) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("隐私政策")
                        }
                    }
                    
                    NavigationLink(destination: TermsOfServiceView()) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text("服务协议")
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("关于我们", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            })
        }
    }
}

// 隐私政策视图
struct PrivacyPolicyView: View {
    var body: some View {
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
                    Text("所有数据均存储在您的设备本地，我们不会将其上传至服务器或第三方共享。")
                    
                    Text("权限说明")
                        .font(.headline)
                    Text("本应用可能需要以下权限：\n• 网络访问：用于获取图书内容\n• 存储权限：用于缓存图书内容，提升阅读体验")
                }
            }
            .padding()
        }
        .navigationBarTitle("隐私政策", displayMode: .inline)
    }
}

// 服务协议视图
struct TermsOfServiceView: View {
    var body: some View {
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
                    Text("用户在使用本应用时需遵守以下规范：\n• 遵守相关法律法规\n• 不得将本应用用于非法用途\n• 尊重知识产权")
                    
                    Text("免责声明")
                        .font(.headline)
                    Text("本应用提供的内容来自互联网，如有侵权请联系我们删除。我们不对内容的准确性、完整性承担责任。")
                }
            }
            .padding()
        }
        .navigationBarTitle("服务协议", displayMode: .inline)
    }
}

struct ReadingHistoryView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var selectedBook: Book?
    @State private var isShowingBookReader = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        List {
            ForEach(viewModel.readingHistory) { record in
                ReadingHistoryItemView(record: record)
                    .onTapGesture {
                        selectedBook = record.book
                    }
            }
            .onDelete(perform: deleteReadingHistory)
        }
        .navigationTitle("阅读记录")
        .navigationBarItems(trailing: Button(action: {
            showingDeleteAlert = true
        }) {
            Text("清空")
                .foregroundColor(.red)
        })
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
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("确认清空"),
                message: Text("确定要清空所有阅读记录吗？此操作不可恢复。"),
                primaryButton: .destructive(Text("清空")) {
                    viewModel.clearAllReadingHistory()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    private func deleteReadingHistory(at offsets: IndexSet) {
        viewModel.deleteReadingHistory(at: offsets)
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
    @State private var showingDeleteAlert = false
    
    var body: some View {
        List {
            ForEach(viewModel.browsingHistory) { record in
                BrowsingHistoryItemView(record: record)
                    .onTapGesture {
                        selectedBook = record.book
                    }
            }
            .onDelete(perform: deleteBrowsingHistory)
        }
        .navigationTitle("浏览记录")
        .navigationBarItems(trailing: Button(action: {
            showingDeleteAlert = true
        }) {
            Text("清空")
                .foregroundColor(.red)
        })
        .onAppear {
            viewModel.refreshBrowsingHistory()
        }
        .sheet(item: $selectedBook) { book in
            BookInfoView(book: book)
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("确认清空"),
                message: Text("确定要清空所有浏览记录吗？此操作不可恢复。"),
                primaryButton: .destructive(Text("清空")) {
                    viewModel.clearAllBrowsingHistory()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    private func deleteBrowsingHistory(at offsets: IndexSet) {
        viewModel.deleteBrowsingHistory(at: offsets)
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
        var history = UserDefaults.standard.readingHistory()
        
        // 使用 Dictionary 的 grouping 特性来实现重
        // 按照 book.id 分组，并只保留每组中最新的记录
        let uniqueHistory = Dictionary(grouping: history) { $0.book.id }
            .values
            .compactMap { records -> ReadingRecord? in
                // 对每组记录按时间排序，取��新的一条
                records.sorted { record1, record2 in
                    // 使用日期比较，确保最新的记录排在前面
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
                    let date1 = dateFormatter.date(from: record1.lastReadTime) ?? Date.distantPast
                    let date2 = dateFormatter.date(from: record2.lastReadTime) ?? Date.distantPast
                    return date1 > date2
                }.first
            }
            .sorted { record1, record2 in
                // 对去重后的记录按时间倒序排序
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
                let date1 = dateFormatter.date(from: record1.lastReadTime) ?? Date.distantPast
                let date2 = dateFormatter.date(from: record2.lastReadTime) ?? Date.distantPast
                return date1 > date2
            }
        
        readingHistory = uniqueHistory
    }
    
    func loadBrowsingHistory() {
        var history = UserDefaults.standard.browsingHistory()
        
        // 对浏览记录执行相同的去重逻辑
        let uniqueHistory = Dictionary(grouping: history) { $0.book.id }
            .values
            .compactMap { records -> BrowsingRecord? in
                records.sorted { record1, record2 in
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
                    let date1 = dateFormatter.date(from: record1.browseTime) ?? Date.distantPast
                    let date2 = dateFormatter.date(from: record2.browseTime) ?? Date.distantPast
                    return date1 > date2
                }.first
            }
            .sorted { record1, record2 in
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
                let date1 = dateFormatter.date(from: record1.browseTime) ?? Date.distantPast
                let date2 = dateFormatter.date(from: record2.browseTime) ?? Date.distantPast
                return date1 > date2
            }
        
        browsingHistory = uniqueHistory
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
        let currentTime = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
        
        let record = BrowsingRecord(
            id: UUID(),
            book: book,
            browseTime: dateFormatter.string(from: currentTime)
        )
        
        // 获取现有的浏览历史
        var browsingHistory = UserDefaults.standard.browsingHistory()
        
        // 移除所有该书的历史记录
        browsingHistory.removeAll { $0.book.id == book.id }
        
        // 加新记录到列表开头
        browsingHistory.insert(record, at: 0)
        
        // 限制历史记录数量
        if browsingHistory.count > 50 {
            browsingHistory = Array(browsingHistory.prefix(50))
        }
        
        // 保存更新后的浏览历史
        UserDefaults.standard.saveBrowsingHistory(browsingHistory)
        
        // 更新发布的属性
        self.browsingHistory = browsingHistory
        
        // 强制刷新视图
        self.objectWillChange.send()
    }
    
    func refreshBrowsingHistory() {
        var history = UserDefaults.standard.browsingHistory()
        
        // 使用 Set 来跟踪已处理的书籍ID
        var processedBookIds = Set<UUID>()
        var uniqueHistory: [BrowsingRecord] = []
        
        // 遍历历史记录，只保留每本书的第一次出现（最新记录）
        for record in history {
            if !processedBookIds.contains(record.book.id) {
                uniqueHistory.append(record)
                processedBookIds.insert(record.book.id)
            }
        }
        
        // 按时间排序
        uniqueHistory.sort { record1, record2 in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
            let date1 = dateFormatter.date(from: record1.browseTime) ?? Date.distantPast
            let date2 = dateFormatter.date(from: record2.browseTime) ?? Date.distantPast
            return date1 > date2
        }
        
        browsingHistory = uniqueHistory
        print("Refreshed browsing history. Current count: \(browsingHistory.count)")
    }
    
    func refreshReadingHistory() {
        readingHistory = UserDefaults.standard.readingHistory()
    }
    
    func clearAllReadingHistory() {
        readingHistory.removeAll()
        UserDefaults.standard.saveReadingHistory(readingHistory)
    }
    
    func clearAllBrowsingHistory() {
        browsingHistory.removeAll()
        UserDefaults.standard.saveBrowsingHistory(browsingHistory)
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
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(white: 0.95), .white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 25) {
                    // 图标部分
                    VStack(spacing: 8) {
                        if let image = UIImage(named: "AppLogo") {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .cornerRadius(16)
                        } else {
                            Image(systemName: "book.closed")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.blue)
                        }
                        
                        Text(Bundle.main.displayName ?? "妙笔阅读")
                            .font(.system(size: 22, weight: .medium))
                        
                        Text("版本：v \(Bundle.main.appVersion)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    // 协议部分
                    VStack(spacing: 0) {
                        NavigationLink(destination: PrivacyPolicyView()) {
                            HStack {
                                Text("隐私协议")
                                    .foregroundColor(.primary)
                                    .padding(.leading, 16)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 16)
                            }
                            .padding(.vertical, 16)
                        }
                        
                        Divider()
                            .padding(.leading, 16)
                        
                        NavigationLink(destination: TermsOfServiceView()) {
                            HStack {
                                Text("服务协议")
                                    .foregroundColor(.primary)
                                    .padding(.leading, 16)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 16)
                            }
                            .padding(.vertical, 16)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitle("关于我们", displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.primary)
            })
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

struct PreloadChapterSelector: View {
    @Binding var preloadChaptersCount: Int
    @Binding var autoPreload: Bool
    @State private var isExpanded = false
    
    private let presetValues = [2, 4, 6, 8, 10] // 章节数选项
    
    var body: some View {
        VStack(spacing: 0) {
            // 主标题区域
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("预加载章节")
                                .font(.selectorTitle)
                            Text("\(preloadChaptersCount)章")
                                .font(.selectorValue)
                                .foregroundColor(.blue)
                        }
                        
                        Text("点击配置预加载数量")
                            .font(.selectorCaption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展开的选择器
            if isExpanded {
                VStack(spacing: 16) {
                    // 选项列表 - 移除 ScrollView，使用固定布局
                    HStack(spacing: 8) {
                        ForEach(presetValues, id: \.self) { value in
                            Button(action: {
                                withAnimation {
                                    preloadChaptersCount = value
                                }
                            }) {
                                Text("\(value)章")
                                    .font(.optionText)
                                    .foregroundColor(preloadChaptersCount == value ? .blue : .gray)
                                    .frame(maxWidth: .infinity) // 确保按钮平均分配宽度
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(preloadChaptersCount == value ? 
                                                 Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(preloadChaptersCount == value ? 
                                                   Color.blue.opacity(0.5) : Color.clear,
                                                   lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    
                    // 警告提示
                    if preloadChaptersCount > 6 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                            Text("预加载过多章节可能会影响性能")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
    }
}

struct UpdateIntervalSelector: View {
    @Binding var checkUpdateInterval: Int
    @Binding var autoCheckUpdate: Bool
    @State private var isExpanded = false
    
    private let intervals = [15, 30, 60, 120] // 分钟
    
    var body: some View {
        VStack(spacing: 0) {
            // 主标题区域
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("检查间隔")
                                .font(.selectorTitle)
                            Text("\(checkUpdateInterval)分钟")
                                .font(.selectorValue)
                                .foregroundColor(.blue)
                        }
                        
                        Text("点击配置检查间隔")
                            .font(.selectorCaption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展开的选择器
            if isExpanded {
                VStack(spacing: 16) {
                    // 选项列表
                    HStack(spacing: 8) {
                        ForEach(intervals, id: \.self) { interval in
                            Button(action: {
                                withAnimation {
                                    checkUpdateInterval = interval
                                }
                            }) {
                                Text("\(interval)分钟")
                                    .font(.optionText)
                                    .foregroundColor(checkUpdateInterval == interval ? .blue : .gray)
                                    .frame(maxWidth: .infinity) // 确保按钮平均分配宽度
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(checkUpdateInterval == interval ? 
                                                 Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(checkUpdateInterval == interval ? 
                                                   Color.blue.opacity(0.5) : Color.clear,
                                                   lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    
                    // 警告提示
                    if checkUpdateInterval < 30 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                            Text("频繁检查可能会增加耗电")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
    }
}
