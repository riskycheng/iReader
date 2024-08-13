import SwiftUI
import Combine
import SwiftSoup

struct ReadingView: View {
    let book: Book
    
    @State private var currentPage = 0
    @State private var article: Article? = nil
    @State private var isLoading = true
    
    @State private var textStyle = TextStyle.defaultStyle
    @State private var htmlParser = HTMLParser(textStyle: TextStyle.defaultStyle)

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if isLoading {
                    Text("Loading...")
                } else if let article = article {
                    TabView(selection: $currentPage) {
                        VStack {
                            Spacer()
                            Text(article.title)
                                .font(.system(size: 28, weight: .bold, design: .default))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)
                            Spacer()
                        }
                        .tag(0)
                        
                        ForEach(0..<article.splitPages.count, id: \.self) { index in
                            VStack {
                                Text(article.splitPages[index])
                                    .font(.system(size: textStyle.font.pointSize))
                                    .lineSpacing(textStyle.lineSpacing)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .padding(.horizontal, 10)
                                    .tag(index + 1)
                                
                                if index == article.splitPages.count - 1 {
                                    HStack {
                                        if let prevLink = article.prevLink {
                                            Button("Prev") {
                                                loadContent(from: prevLink, width: geometry.size.width, height: geometry.size.height)
                                            }
                                        }
                                        Spacer()
                                        if let nextLink = article.nextLink {
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
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    Text("Current Page: \(currentPage + 1)/\(article.pagesCount + 1)").padding()
                }
            }
            .onAppear {
                loadContent(from: book.link, width: geometry.size.width, height: geometry.size.height)
            }
            .navigationBarHidden(true) // Hide the navigation bar
        }
    }

    private func loadContent(from urlString: String, width: CGFloat, height: CGFloat) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        // Extract the base URL by combining the scheme and host
        let baseURL = "\(url.scheme ?? "https")://\(url.host ?? "")"

        // Reset the current page and article cache before loading new content
        DispatchQueue.main.async {
            self.currentPage = 0
            self.article = nil
            self.isLoading = true
        }

        let session = URLSession(configuration: .default)
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error loading URL: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            var parser = htmlParser // Make a local mutable copy of htmlParser
            switch parser.parseHTML(data: data, baseURL: baseURL, width: width, height: height - parser.measureSingleLineWithTwoLineSpacesHeight()) {
            case .success(let article):
                DispatchQueue.main.async {
                    self.article = article // Store the article
                    self.isLoading = false
                }
            case .failure(let error):
                print("Parsing error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
}

#Preview {
    ReadingView(book: Book(title: "Sample Book", link: "https://example.com/book1", cover: "sampleCover", introduction: "This is a sample introduction."))
}
