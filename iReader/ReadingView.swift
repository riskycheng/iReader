import SwiftUI
import Combine
import SwiftSoup

struct TextHeightMeasurer: View {
    let text: String
    let width: CGFloat
    
    @State private var height: CGFloat = .zero
    
    var body: some View {
        Text(text)
            .frame(width: width, alignment: .leading)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: HeightPreferenceKey.self, value: geometry.size.height)
            })
            .onPreferenceChange(HeightPreferenceKey.self) { height in
                self.height = height
            }
    }
}

struct HeightPreferenceKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


struct ReadingView: View {
    @State private var currentPage = 0
    @State private var pages: [String] = []
    @State private var isLoading = true
    @State private var containerWidth: CGFloat = UIScreen.main.bounds.width
    @State private var containerHeight: CGFloat = UIScreen.main.bounds.height

    var body: some View {
        VStack {
            if isLoading {
                Text("Loading...")
            } else {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        Text(pages[index])
                            .tag(index)
                            .padding()
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                Text("Current Page: \(currentPage + 1)/\(pages.count)").padding()
            }
        }
        .onAppear(perform: loadContent)
    }

    private func loadContent() {
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
                    self.pages = self.splitContentIntoPages(content: content, width: self.containerWidth, height: self.containerHeight)
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

    private func splitContentIntoPages(content: String, width: CGFloat, height: CGFloat) -> [String] {
        let words = content.split(separator: " ")
        var pages: [String] = []
        var currentPageContent = ""
        var currentPageHeight: CGFloat = 0

        let maxHeight = height - 40 // Adjust for padding and other UI elements

        for word in words {
            let testContent = currentPageContent + "\(word) "
            let textHeight = measureTextHeight(text: testContent, width: width)

            if currentPageHeight + textHeight > maxHeight {
                pages.append(currentPageContent.trimmingCharacters(in: .whitespaces))
                currentPageContent = "\(word) "
                currentPageHeight = measureTextHeight(text: "\(word) ", width: width)
            } else {
                currentPageContent += "\(word) "
                currentPageHeight = textHeight
            }
        }

        if !currentPageContent.isEmpty {
            pages.append(currentPageContent.trimmingCharacters(in: .whitespaces))
        }

        print("Parsed \(pages.count) pages")
        return pages
    }

    private func measureTextHeight(text: String, width: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 17)
        let constraintRect = CGSize(width: width - 40, height: .greatestFiniteMagnitude) // 40 is for padding
        let boundingBox = text.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
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
