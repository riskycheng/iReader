import SwiftUI

struct ReadingView: View {
    let book: Book
    let chapterLink: String?
    @Binding var isReadingViewActive: Bool

    @State private var currentPage = 0
    @State private var article: Article? = nil
    @State private var isLoading = true
    @State private var selectedBackgroundColor: Color = .white
    @State private var selectedFontSize: CGFloat = 18

    private let topToolbarHeight: CGFloat = 44
    private let bottomToolbarHeight: CGFloat = 40
    private let pageContentPadding: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                selectedBackgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Bar: Book Name and Chapter Name
                    HStack {
                        Button(action: {
                            isReadingViewActive = false
                        }) {
                            Text(book.title)
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.leading)
                        
                        Spacer()
                        
                        Text(article?.title ?? "")
                            .font(.headline)
                            .foregroundColor(.black)
                        
                        Spacer()
                    }
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .frame(height: topToolbarHeight)

                    // Central Content Area
                    if isLoading {
                        ProgressView("Loading...")
                            .progressViewStyle(CircularProgressViewStyle())
                    } else if let article = article {
                        TabView(selection: $currentPage) {
                            ForEach(0..<article.splitPages.count, id: \.self) { index in
                                ScrollView {
                                    Text(article.splitPages[index])
                                        .font(.system(size: selectedFontSize))
                                        .lineSpacing(5)
                                        .padding(.horizontal, pageContentPadding)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                        .frame(height: geometry.size.height - topToolbarHeight - bottomToolbarHeight)
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    }

                    // Bottom Bar: Battery Status and Page Indexer
                    HStack {
                        // Battery Status (Placeholder)
                        HStack(spacing: 2) {
                            Image(systemName: "battery.100")
                            Text("22:03") // You might want to update this to fetch real-time battery status
                                .font(.caption)
                        }
                        .foregroundColor(.gray)

                        Spacer()

                        // Page Indexer
                        if let article = article {
                            Text("\(currentPage + 1)/\(article.splitPages.count) (\(String(format: "%.2f", Double(currentPage + 1) / Double(article.splitPages.count) * 100))%)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 5)
                    .frame(height: bottomToolbarHeight)
                    .background(Color.white.opacity(0.9))
                }
            }
            .onAppear {
                if let chapterLink = chapterLink {
                    loadContent(from: chapterLink, width: geometry.size.width, height: geometry.size.height - topToolbarHeight - bottomToolbarHeight)
                }
            }
        }
        .navigationBarHidden(true)
        .edgesIgnoringSafeArea(.all) // Ensures full-screen content
    }

    private func loadContent(from link: String, width: CGFloat, height: CGFloat) {
        guard let url = URL(string: link) else { return }

        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("ReadingView: Failed to load content - \(error.localizedDescription)")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            if let data = data {
                let parser = HTMLParser()
                switch parser.parseHTML(data: data, baseURL: link, width: width, height: height - pageContentPadding, toolbarHeight: 0) {
                case .success(let article):
                    DispatchQueue.main.async {
                        self.article = article
                        self.isLoading = false
                        self.currentPage = 0
                    }
                case .failure(let error):
                    print("ReadingView: Parsing error - \(error)")
                    DispatchQueue.main.async { self.isLoading = false }
                }
            } else {
                print("ReadingView: No data received from URL.")
                DispatchQueue.main.async { self.isLoading = false }
            }
        }.resume()
    }
}
