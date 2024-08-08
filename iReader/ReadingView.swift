import SwiftUI
import Combine
import SwiftSoup

struct ReadingView: View {
    @State private var currentPage = 0
    @State private var pages: [String] = []
    @State private var isLoading = true

    var body: some View {
        VStack {
            if isLoading {
                Text("Loading...")
            } else {
                PageView(pages: pages, currentPage: $currentPage)
                    .tabViewStyle(PageTabViewStyle())
                Text("Current Page: \(currentPage + 1)").padding()
            }
        }.onAppear(perform: loadContent)
    }

    private func loadContent() {
        guard let url = URL(string: "https://www.bqgui.cc/book/1594/1.html") else {
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
                let parsedPages = parseContentIntoPages(content)
                DispatchQueue.main.async {
                    if parsedPages.isEmpty {
                        self.pages = ["Failed to parse content."]
                    } else {
                        self.pages = parsedPages
                    }
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

    private func parseContentIntoPages(_ content: String) -> [String] {
        print("Parsing content")

        do {
            let doc: Document = try SwiftSoup.parse(content)
            // Update the selector based on the actual HTML structure
            guard let bodyContent: Element = try doc.select("div.content").first() else { // Adjust this selector based on actual HTML structure
                print("Failed to find content range")
                return []
            }
            let textContent = try bodyContent.text()
            print("Cleaned content: \(textContent.prefix(200))...") // Print first 200 characters

            let words = textContent.split(separator: " ")
            let wordsPerPage = 200
            var pages: [String] = []
            var currentPageContent = ""

            for (index, word) in words.enumerated() {
                currentPageContent += "\(word) "
                if (index + 1) % wordsPerPage == 0 || index == words.count - 1 {
                    pages.append(currentPageContent)
                    currentPageContent = ""
                }
            }

            print("Parsed \(pages.count) pages")
            return pages

        } catch {
            print("Error parsing content: \(error)")
            return ["Failed to parse content due to error: \(error.localizedDescription)"]
        }
    }
}

struct PageView: View {
    var pages: [String]
    @Binding var currentPage: Int

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(pages.indices, id: \.self) { index in
                Text(pages[index])
                    .tag(index) // Ensure tag is correctly set
                    .padding()
            }
        }.tabViewStyle(PageTabViewStyle())
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
