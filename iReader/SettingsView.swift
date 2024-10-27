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
    var body: some View {
        VStack(spacing: 20) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
            
            Text("妙笔阅读")
                .font(.title)
                .fontWeight(.bold)
            
            Text("版本: v1.3.60")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("妙笔阅读是一款专注于提供优质阅读体验的应用。我们致力于为用户带来丰富的内容和便捷的阅读功能。")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
        }
        .padding()
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
