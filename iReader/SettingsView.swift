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
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            ForEach(viewModel.readingHistory, id: \.id) { record in
                ReadingHistoryItemView(record: record)
            }
            .onDelete(perform: viewModel.deleteReadingHistory)
        }
        .navigationTitle("阅读记录")
        .navigationBarItems(trailing: EditButton())
        .environment(\.editMode, $editMode)
        .onAppear {
            viewModel.loadReadingHistory()
        }
    }
}

struct ReadingHistoryItemView: View {
    let record: ReadingRecord
    @State private var coverImage: UIImage?

    var body: some View {
        HStack {
            if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 80)
                    .cornerRadius(5)
            } else {
                Image(systemName: "book")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 80)
                    .cornerRadius(5)
                    .onAppear {
                        loadCoverImage()
                    }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(record.book.title)
                    .font(.headline)
                Text(record.book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("上次阅读: \(record.lastChapter)")
                    .font(.caption)
                Text("阅读时间: \(record.lastReadTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func loadCoverImage() {
        guard let url = URL(string: record.book.coverURL) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.coverImage = image
                }
            }
        }.resume()
    }
}

struct BrowsingHistoryView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            ForEach(viewModel.browsingHistory, id: \.id) { record in
                BrowsingHistoryItemView(record: record)
            }
            .onDelete(perform: viewModel.deleteBrowsingHistory)
        }
        .navigationTitle("浏览记录")
        .navigationBarItems(trailing: EditButton())
        .environment(\.editMode, $editMode)
    }
}

struct BrowsingHistoryItemView: View {
    let record: BrowsingRecord
    @State private var coverImage: UIImage?

    var body: some View {
        HStack {
            if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 80)
                    .cornerRadius(5)
            } else {
                Image(systemName: "book")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 80)
                    .cornerRadius(5)
                    .onAppear {
                        loadCoverImage()
                    }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(record.book.title)
                    .font(.headline)
                Text(record.book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("浏览时间: \(record.browseTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func loadCoverImage() {
        guard let url = URL(string: record.book.coverURL) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.coverImage = image
                }
            }
        }.resume()
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
