import SwiftUI
import Combine
import SwiftSoup

struct ReadingView: View {
    @State private var currentPage = 0
    @State private var pages: [String] = []
    @State private var isLoading = true
    @State private var originalContent: String = "" // Store the original content
    
    @State private var textStyle = TextStyle.defaultStyle
    @State private var htmlParser = HTMLParser(textStyle: TextStyle.defaultStyle)

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if isLoading {
                    Text("Loading...")
                } else {
                    TabView(selection: $currentPage) {
                        ForEach(pages.indices, id: \.self) { index in
                            VStack {
                                Text(pages[index])
                                    .font(.system(size: textStyle.font.pointSize))
                                    .lineSpacing(textStyle.lineSpacing)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .padding(.horizontal, 10)
                                    .tag(index)
                                
                                // Add Prev and Next buttons at the end of the last page
                                if index == pages.count - 1 {
                                    HStack {
                                        if let prevLink = htmlParser.prevLink {
                                            Button("Prev") {
                                                loadContent(from: prevLink, width: geometry.size.width, height: geometry.size.height)
                                            }
                                        }
                                        Spacer()
                                        if let nextLink = htmlParser.nextLink {
                                            Button("Next") {
                                                loadContent(from: nextLink, width: geometry.size.width, height: geometry.size.height)
                                            }
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Remove page switching indicators
                    Text("Current Page: \(currentPage + 1)/\(pages.count)").padding()
                }
            }
            .onAppear {
                loadContent(from: "https://www.bqgui.cc/book/136867/13.html", width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private func loadContent(from urlString: String, width: CGFloat, height: CGFloat) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        // Extract the base URL by combining the scheme and host
        let baseURL = "\(url.scheme ?? "https")://\(url.host ?? "")"

        // Reset the current page and pages cache before loading new content
        DispatchQueue.main.async {
            self.currentPage = 0
            self.pages = []
            self.isLoading = true
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

            var parser = htmlParser // Make a local mutable copy of htmlParser
            switch parser.parseHTML(data: data, baseURL: baseURL) {
            case .success(let content):
                DispatchQueue.main.async {
                    self.originalContent = content // Store original content
                    self.pages = parser.splitContentIntoPages(content: content, width: width, height: height - parser.measureSingleLineWithTwoLineSpacesHeight())
                    self.htmlParser = parser // Update the state with the modified parser
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
