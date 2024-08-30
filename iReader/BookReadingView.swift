import SwiftUI

struct BookReadingView: View {
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @State private var pages: [String] = []
    
    var bookName: String = "万相之王"
    var chapterName: String = "第一章 我有三个相宫"
    var bookContent: String = BookContent.fullContent
    
    let fontSize: CGFloat = 20
    let lineSpacing: CGFloat = 8
    
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
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(pages[index])
                                .font(.custom("Georgia", size: fontSize))
                                .lineSpacing(lineSpacing)
                                .frame(width: geometry.size.width - 40, alignment: .topLeading)
                                .padding(.horizontal, 20)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height - 100)
                        .background(Color.brown)
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
        let contentSize = CGSize(width: screenSize.width - 40, height: screenSize.height - 100)
        let font = UIFont(name: "Georgia", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        
        pages = BookUtils.splitContentIntoPages(content: bookContent, size: contentSize, font: font, lineSpacing: lineSpacing)
        totalPages = pages.count
    }
}

struct BookReadingView_Previews: PreviewProvider {
    static var previews: some View {
        BookReadingView()
    }
}
