import SwiftUI
import Combine
import SwiftSoup

struct ReadingView: View {
    @State private var currentPage = 0
    @State private var pages: [String] = []
    @State private var isLoading = true
    
    // Use the default style, but you can customize it as needed
    var textStyle = TextStyle.defaultStyle

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if isLoading {
                    Text("Loading...")
                } else {
                    TabView(selection: $currentPage) {
                        ForEach(pages.indices, id: \.self) { index in
                            Text(pages[index])
                                .font(.system(size: textStyle.font.pointSize)) // Use configured font size
                                .lineSpacing(textStyle.lineSpacing)           // Use configured line spacing
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(.horizontal, 10)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle())
                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .never)) // Hides the dots
                    Text("Current Page: \(currentPage + 1)/\(pages.count)").padding()
                }
            }
            .onAppear {
                let singleLineHeight = measureSingleLineHeight(width: geometry.size.width)
                loadContent(width: geometry.size.width, height: geometry.size.height - singleLineHeight, geometry: geometry)
            }
        }
    }

    private func loadContent(width: CGFloat, height: CGFloat, geometry: GeometryProxy) {
        guard let url = URL(string: "https://www.bqgui.cc/book/879/5.html") else {
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
        let availableHeight = height - safeAreaInsets.top - safeAreaInsets.bottom // Adjusting for any other UI elements like the bottom text
    
        let cleanedContent = cleanHTMLTags(from: content)
        let words = cleanedContent.split(separator: " ")
        var pages: [String] = []
        var currentPageContent = ""

        for word in words {
            let testContent = currentPageContent.isEmpty ? "\(word)" : "\(currentPageContent) \(word)"
            let textHeight = measureTextHeight(text: testContent, width: width)

            if textHeight > availableHeight {
                if currentPageContent.isEmpty {
                    pages.append(testContent)
                    currentPageContent = ""
                } else {
                    pages.append(currentPageContent)
                    currentPageContent = "\(word)"
                }
            } else {
                currentPageContent = testContent
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
        let constraintRect = CGSize(width: width - 20, height: .greatestFiniteMagnitude) // Adjust for padding
        let boundingBox = text.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: textStyle.font, .paragraphStyle: textStyle.paragraphStyle], context: nil)
        return ceil(boundingBox.height)
    }

    private func measureSingleLineHeight(width: CGFloat) -> CGFloat {
        let singleLineText = "Sample Text" // Sample text to measure
        let constraintRect = CGSize(width: width - 20, height: .greatestFiniteMagnitude)
        let boundingBox = singleLineText.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: textStyle.font, .paragraphStyle: textStyle.paragraphStyle], context: nil)
        return ceil(boundingBox.height)
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
