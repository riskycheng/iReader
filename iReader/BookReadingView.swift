import SwiftUI

struct BookReadingView: View {
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @State private var pages: [String] = []
    
    var bookName: String = "万相之王"
    var chapterName: String = "第一章 我有三个相宫"
    var bookContent: String = BookContent.fullContent
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top Bar with Book Name and Chapter Name
                HStack {
                    Text(bookName)
                        .font(.headline)
                    Spacer()
                    Text(chapterName)
                        .font(.headline)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 5)
                
                // Content Display
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Text(pages[index])
                            .font(.system(size: 18))
                            .padding(.horizontal, 20)
                            .frame(width: geometry.size.width, height: geometry.size.height - 80, alignment: .top)
                            .tag(index + 1)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Bottom Bar with Battery Status and Page Indexer
                HStack {
                    // Battery Status
                    HStack {
                        Image(systemName: "battery.100")
                        Text("100%")
                    }
                    Spacer()
                    // Page Indexer
                    Text("\(currentPage) / \(totalPages)")
                }
                .font(.footnote)
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            splitContentIntoPages()
        }
    }
    
    private func splitContentIntoPages() {
        let screenSize = UIScreen.main.bounds.size
        let contentSize = CGSize(width: screenSize.width - 40, height: screenSize.height - 80)
        let font = UIFont.systemFont(ofSize: 18)
        
        pages = BookUtils.splitContentIntoPages(content: bookContent, size: contentSize, font: font)
        totalPages = pages.count
    }
}

struct BookReadingView_Previews: PreviewProvider {
    static var previews: some View {
        BookReadingView()
    }
}
