import SwiftUI
import Combine
import SwiftSoup

struct ReadingView: View {
    @State private var currentPage = 0
    @State private var pages: [String] = []
    @State private var isLoading = true
    @State private var originalContent: String = "" // Store the original content
    
    @State private var textStyle = TextStyle.defaultStyle
        private let htmlParser: HTMLParser
    
    init() {
           self.htmlParser = HTMLParser(textStyle: TextStyle.defaultStyle)
       }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if isLoading {
                    Text("Loading...")
                } else {
                    TabView(selection: $currentPage) {
                        ForEach(pages.indices, id: \.self) { index in
                            Text(pages[index])
                                .font(.system(size: textStyle.font.pointSize))
                                .lineSpacing(textStyle.lineSpacing)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(.horizontal, 10)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Remove page switching indicators
                    Text("Current Page: \(currentPage + 1)/\(pages.count)").padding()
                }
            }
            .onAppear {
                loadContent(width: geometry.size.width, height: geometry.size.height - self.htmlParser.measureSingleLineWithTwoLineSpacesHeight())
            }
        }
    }

    private func loadContent(width: CGFloat, height: CGFloat) {
        guard let url = URL(string: "https://www.bqgui.cc/book/136867/13.html") else {
            print("Invalid URL")
            return
        }

        let session = URLSession(configuration: .default)
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error loading URL: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.pages = ["Failed to load content due to network error: \(error.localizedDescription)"]
                    self.isLoading = false
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.pages = ["Failed to load content due to no data received."]
                    self.isLoading = false
                }
                return
            }

            switch self.htmlParser.parseHTML(data: data) {
            case .success(let content):
                DispatchQueue.main.async {
                    self.originalContent = content // Store original content
                    self.pages = self.htmlParser.splitContentIntoPages(content: content, width: width, height: height)
                    self.isLoading = false
                }
            case .failure(let error):
                print("Parsing error: \(error)")
                DispatchQueue.main.async {
                    self.pages = ["Failed to parse content."]
                    self.isLoading = false
                }
            }
        }.resume()
    }
}

#Preview {
    ReadingView()
}
