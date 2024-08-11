import SwiftUI
import Combine
import SwiftSoup

struct ReadingView: View {
    @State private var currentPage = 0
    @State private var pages: [String] = []
    @State private var isLoading = true
    @State private var originalContent: String = "" // Store the original content
    
    @State private var textStyle = TextStyle.defaultStyle
    @State private var textSize: CGFloat = 17
    @State private var lineSpacing: CGFloat = 1.5

    private let htmlParser = HTMLParser()

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
                    .tabViewStyle(PageTabViewStyle())
                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .never))
                    Text("Current Page: \(currentPage + 1)/\(pages.count)").padding()

                    HStack {
                        Text("Text Size: \(Int(textSize))")
                        Slider(value: $textSize, in: 10...30, step: 1) {
                            Text("Text Size")
                        }
                        .onChange(of: textSize) { newSize in
                            textStyle.setFont(.systemFont(ofSize: newSize))
                            reloadPages(with: geometry)
                        }
                    }.padding()

                    HStack {
                        Text("Line Spacing: \(lineSpacing, specifier: "%.1f")")
                        Slider(value: $lineSpacing, in: 1...3, step: 0.1) {
                            Text("Line Spacing")
                        }
                        .onChange(of: lineSpacing) { newSpacing in
                            textStyle.setLineSpacing(newSpacing)
                            reloadPages(with: geometry)
                        }
                    }.padding()
                }
            }
            .onAppear {
                let singleLineHeight = measureSingleLineHeight(width: geometry.size.width)
                loadContent(width: geometry.size.width, height: geometry.size.height - singleLineHeight)
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
                    self.pages = self.htmlParser.splitContentIntoPages(content: content, width: width, height: height, textStyle: self.textStyle)
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

    private func reloadPages(with geometry: GeometryProxy) {
        let singleLineHeight = measureSingleLineHeight(width: geometry.size.width)
        let availableHeight = geometry.size.height - singleLineHeight
        self.pages = self.htmlParser.splitContentIntoPages(content: originalContent, width: geometry.size.width, height: availableHeight, textStyle: textStyle)
        self.currentPage = 0
    }

    private func measureSingleLineHeight(width: CGFloat) -> CGFloat {
        let singleLineText = "Sample Text"
        let constraintRect = CGSize(width: width - 20, height: .greatestFiniteMagnitude)
        let boundingBox = singleLineText.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: textStyle.font, .paragraphStyle: textStyle.paragraphStyle], context: nil)
        return ceil(boundingBox.height)
    }
}


#Preview {
    ReadingView()
}
