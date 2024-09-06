import SwiftUI
import Combine

struct BookStoreView: View {
    @State private var searchText = ""
    @StateObject private var viewModel = BookStoreViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    if searchText.isEmpty {
                        VStack(spacing: 20) {
                            // Featured sections (unchanged)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                FeaturedItem(title: "在读榜", subtitle: "Top List", color: .black)
                                FeaturedItem(title: "新书榜", subtitle: "New Release", color: .gray)
                                FeaturedItem(title: "共读", subtitle: "Reading Lab", color: .gray)
                                FeaturedItem(title: "故事", subtitle: "My Story", color: .green)
                            }
                            .padding()
                            
                            // Categories (unchanged)
                            Text("分类")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                CategoryItem(title: "Turbo专享", color: .gray)
                                CategoryItem(title: "豆瓣8.0+", color: .green)
                                CategoryItem(title: "小说", color: .brown)
                                CategoryItem(title: "漫画绘本", color: .orange)
                                CategoryItem(title: "青春", color: .pink)
                                CategoryItem(title: "推理幻想", color: .gray)
                                CategoryItem(title: "短篇集", color: .gray)
                                CategoryItem(title: "历史", color: .gray)
                                CategoryItem(title: "国风文化", color: .gray)
                            }
                            .padding()
                        }
                    } else {
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                        } else {
                            List(viewModel.searchResults, id: \.title) { book in
                                BookSearchResultView(book: book)
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "搜索")
                .onSubmit(of: .search) {
                    print("Search submitted with query: \(searchText)")
                    if !searchText.isEmpty {
                        viewModel.search(query: searchText)
                    }
                }
                .onChange(of: searchText) { newValue in
                    if newValue.isEmpty {
                        viewModel.clearResults()
                    }
                }
                .navigationTitle("书城")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    struct BookSearchResultView: View {
        let book: Book
        
        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                // Book cover image
                AsyncImage(url: URL(string: book.coverURL)) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 80, height: 120)
                .cornerRadius(5)
                
                // Book details
                VStack(alignment: .leading, spacing: 5) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text(book.author)
                        .font(.subheadline)
                    Text(book.introduction)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("说说520等 共2个书源")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("查看全部 >") {
                            // Action to view all details
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                // Right-aligned button
                VStack {
                    Button(action: {
                        // Action for 说说520 button
                    }) {
                        Text("说说520")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(15)
                    }
                    Spacer()
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    class BookStoreViewModel: ObservableObject {
        @Published var searchResults: [Book] = []
         @Published var errorMessage: String?
         @Published var isLoading: Bool = false
         private let baseURL = "https://www.bqgda.cc"
         private var cancellables = Set<AnyCancellable>()
        
        func search(query: String) {
            print("Starting search for query: \(query)")
            guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "\(baseURL)/s?q=\(encodedQuery)") else {
                print("Failed to create URL for query: \(query)")
                self.errorMessage = "Invalid search query"
                return
            }
            
            isLoading = true
            errorMessage = nil
            searchResults.removeAll()
            
            fetchSearchResults(url: url)
        }
        
        private func fetchSearchResults(url: URL) {
            URLSession.shared.dataTaskPublisher(for: url)
                .map { $0.data }
                .map { String(data: $0, encoding: .utf8) ?? "" }
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        self?.errorMessage = "Error: \(error.localizedDescription)"
                        self?.isLoading = false
                    }
                }, receiveValue: { [weak self] htmlString in
                    self?.parseInitialHTML(htmlString)
                    self?.pollForResults(url: url)
                })
                .store(in: &cancellables)
        }
        
        private func parseInitialHTML(_ html: String) {
            print("Received initial HTML. Length: \(html.count)")
            // You can add more parsing here if needed
        }
        
        private func pollForResults(url: URL) {
            Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.checkForResults(url: url)
                }
                .store(in: &cancellables)
        }
        
        private func checkForResults(url: URL) {
                URLSession.shared.dataTaskPublisher(for: url)
                    .map { $0.data }
                    .map { String(data: $0, encoding: .utf8) ?? "" }
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.errorMessage = "Error: \(error.localizedDescription)"
                            self?.isLoading = false
                        }
                    }, receiveValue: { [weak self] htmlString in
                        guard let self = self else { return }
                        let books = HTMLSearchParser.parseSearchResults(html: htmlString, baseURL: self.baseURL)
                        print("ViewModel received \(books.count) books")
                        for (index, book) in books.enumerated() {
                            print("Book \(index + 1) in ViewModel:")
                            print("  Title: \(book.title)")
                            print("  Author: \(book.author)")
                            print("  Cover URL: \(book.coverURL)")
                            print("  Introduction: \(book.introduction)")
                            print("  Link: \(book.link)")
                        }
                        if !books.isEmpty {
                            self.searchResults = books
                            self.isLoading = false
                            self.cancellables.removeAll()  // Stop polling
                        }
                    })
                    .store(in: &cancellables)
            }
        
        func clearResults() {
            print("Clearing search results")
            searchResults.removeAll()
            errorMessage = nil
            isLoading = false
            cancellables.removeAll()
        }
    }
    
    struct BookSearchResult {
        let title: String
        let author: String
        let coverURL: String
    }
    
    struct FeaturedItem: View {
        let title: String
        let subtitle: String
        let color: Color
        
        var body: some View {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(color)
                    .frame(height: 120)
                    .cornerRadius(10)
                
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
            }
        }
    }
    
    struct CategoryItem: View {
        let title: String
        let color: Color
        
        var body: some View {
            VStack {
                Rectangle()
                    .fill(color)
                    .frame(height: 100)
                    .cornerRadius(10)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
    }
    
    
    
    
}
struct BookStoreView_Previews: PreviewProvider {
    static var previews: some View {
        BookStoreView()
    }
}


extension Color {
    static let charcoal = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let tan = Color(red: 0.82, green: 0.71, blue: 0.55)
    static let navy = Color(red: 0.0, green: 0.0, blue: 0.5)
    static let darkRed = Color(red: 0.5, green: 0.0, blue: 0.0)
}
