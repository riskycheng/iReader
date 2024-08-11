import SwiftUI
import Combine
import SwiftSoup

struct ReadingView: View {
    @State private var currentPage = 0
    @State private var pages: [String] = []
    @State private var isLoading = true
    
    @State private var textStyle = TextStyle.defaultStyle
    @State private var textSize: CGFloat = 17
    @State private var lineSpacing: CGFloat = 1.5

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
                        .onChange(of: textSize) { newSize, _ in
                            textStyle.setFont(.systemFont(ofSize: newSize))
                            reloadPages(with: geometry)
                        }
                    }.padding()

                    HStack {
                        Text("Line Spacing: \(lineSpacing, specifier: "%.1f")")
                        Slider(value: $lineSpacing, in: 1...3, step: 0.1) {
                            Text("Line Spacing")
                        }
                        .onChange(of: lineSpacing) { newSpacing, _ in
                            textStyle.setLineSpacing(newSpacing)
                            reloadPages(with: geometry)
                        }
                    }.padding()
                }
            }
            .onAppear {
                let singleLineHeight = measureSingleLineHeight(width: geometry.size.width)
                loadContent(width: geometry.size.width, height: geometry.size.height - singleLineHeight, geometry: geometry)
            }
        }
    }

    private func loadContent(width: CGFloat, height: CGFloat, geometry: GeometryProxy) {
        guard let url = URL(string: "https://www.bqgui.cc/book/136867/13.html") else {
            print("Invalid URL")
            return
        }

        let session = URLSession(configuration: .default, delegate: SSLPinningDelegate(), delegateQueue: nil)
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error loading URL: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.pages = ["Failed to load content due to network error: \(error.localizedDescription)"]
                    self.isLoading = false
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Response Status Code: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    DispatchQueue.main.async {
                        self.pages = ["Failed to load content: HTTP status code \(httpResponse.statusCode)"]
                        self.isLoading = false
                    }
                    return
                }
            }

            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async {
                    self.pages = ["Failed to load content due to no data received."]
                    self.isLoading = false
                }
                return
            }

            var content: String? = nil
            if let decodedContent = String(data: data, customEncoding: .gbk) {
                content = decodedContent
            } else if let decodedContent = String(data: data, encoding: .utf8) {
                content = decodedContent
            } else if let decodedContent = String(data: data, encoding: .isoLatin1) {
                content = decodedContent
            }

            if let content = content {
                print("Decoded content: \(content.prefix(200))...") // Print first 200 characters
                DispatchQueue.main.async {
                    self.pages = self.splitContentIntoPages(content: content, width: width, height: height, geometry: geometry)
                    self.isLoading = false
                }
            } else {
                print("Failed to decode data with any encoding")
                DispatchQueue.main.async {
                    self.pages = ["Failed to load content due to data decoding error."]
                    self.isLoading = false
                }
            }
        }.resume()
    }

    private func splitContentIntoPages(content: String, width: CGFloat, height: CGFloat, geometry: GeometryProxy) -> [String] {
        let safeAreaInsets = geometry.safeAreaInsets
        let availableHeight = height - safeAreaInsets.top - safeAreaInsets.bottom
    
        let cleanedContent = cleanHTMLTags(from: content)
        let words = cleanedContent.split(separator: " ")
        var pages: [String] = []
        var currentPageContent = ""
        var currentPageHeight: CGFloat = 0

        for word in words {
            let testContent = currentPageContent.isEmpty ? "\(word)" : "\(currentPageContent) \(word)"
            let textHeight = measureTextHeight(text: testContent, width: width)

            if currentPageHeight + textHeight > availableHeight {
                if currentPageContent.isEmpty {
                    pages.append(testContent)
                    currentPageContent = ""
                    currentPageHeight = textHeight
                } else {
                    pages.append(currentPageContent)
                    currentPageContent = "\(word)"
                    currentPageHeight = measureTextHeight(text: currentPageContent, width: width)
                }
            } else {
                currentPageContent = testContent
                currentPageHeight = textHeight
            }
        }

        if !currentPageContent.isEmpty {
            pages.append(currentPageContent)
        }

        print("Parsed \(pages.count) pages")
        return pages
    }

    private func cleanHTMLTags(from text: String) -> String {
        do {
            let doc: Document = try SwiftSoup.parse(text)
            return try doc.text()
        } catch {
            print("Error cleaning HTML tags: \(error)")
            return text
        }
    }

    private func measureTextHeight(text: String, width: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: width - 20, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: textStyle.font, .paragraphStyle: textStyle.paragraphStyle], context: nil)
        return ceil(boundingBox.height)
    }

    private func measureSingleLineHeight(width: CGFloat) -> CGFloat {
        let singleLineText = "Sample Text"
        let constraintRect = CGSize(width: width - 20, height: .greatestFiniteMagnitude)
        let boundingBox = singleLineText.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: textStyle.font, .paragraphStyle: textStyle.paragraphStyle], context: nil)
        return ceil(boundingBox.height)
    }

    private func reloadPages(with geometry: GeometryProxy) {
        let singleLineHeight = measureSingleLineHeight(width: geometry.size.width)
        let availableHeight = geometry.size.height - singleLineHeight
        self.pages = self.splitContentIntoPages(content: pages.joined(separator: " "), width: geometry.size.width, height: availableHeight, geometry: geometry)
        self.currentPage = 0
    }
}

extension String {
    init?(data: Data, customEncoding encoding: String.Encoding) {
        if encoding == .gbk {
            let cfEncoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            if let string = NSString(data: data, encoding: nsEncoding) as String? {
                self = string
                return
            } else {
                return nil
            }
        } else {
            self.init(data: data, encoding: encoding)
        }
    }
}

extension String.Encoding {
    static let gbk = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
}

class SSLPinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}

#Preview {
    ReadingView()
}
