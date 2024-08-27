import SwiftUI

struct BookReadingView: View {
    let bookTitle: String
    let chapterTitle: String
    let content: String
    
    @State private var currentPage = 0
    @State private var pages: [String] = []
    @State private var batteryLevel: Float = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack {
                    Text(bookTitle)
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(chapterTitle)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                if !pages.isEmpty {
                    TabView(selection: $currentPage) {
                        // First page with chapter title at the top and content below
                        VStack(alignment: .center) {
                            Text(chapterTitle)
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 8)
                            
                            ScrollView {
                                Text(pages[0])
                                    .padding(.horizontal)
                                    .frame(width: geometry.size.width - 32, alignment: .topLeading)
                            }
                            Spacer()
                        }
                        .tag(0)
                        
                        // Additional content pages
                        ForEach(1..<pages.count, id: \.self) { index in
                            ScrollView {
                                Text(pages[index])
                                    .padding()
                                    .frame(width: geometry.size.width - 32, alignment: .topLeading)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                } else {
                    Text("Loading content...") // Placeholder in case pages are not yet populated
                        .padding()
                }
                
                HStack {
                    Text("Battery: \(Int(batteryLevel * 100))%")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Page \(currentPage + 1)/\(pages.count)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            self.batteryLevel = UIDevice.current.batteryLevel
            self.pages = splitIntoPages(content: content, geometrySize: UIScreen.main.bounds.size)
            
            // Debugging print to check pages content
            print("Pages generated: \(pages.count)")
            for (index, page) in pages.enumerated() {
                print("Page \(index + 1) contains \(page.count) characters")
            }
        }
        .onDisappear {
            UIDevice.current.isBatteryMonitoringEnabled = false
        }
    }
    
    // Improved content splitting logic
    func splitIntoPages(content: String, geometrySize: CGSize) -> [String] {
        let font = UIFont.systemFont(ofSize: 17)
        let titleHeight = TextHeightMeasurer.calculateHeight(for: chapterTitle, width: geometrySize.width - 32, font: UIFont.systemFont(ofSize: 24))
        let availableHeightForFirstPage = geometrySize.height - titleHeight - 120 // Adjust for padding and title
        let availableHeightForOtherPages = geometrySize.height - 120 // Adjust for padding

        var pages: [String] = []
        var currentPageContent = ""
        var currentHeight: CGFloat = 0
        
        let words = content.split(separator: " ").map { String($0) }

        // Handle the first page separately to include the chapter title
        for word in words {
            let testContent = currentPageContent.isEmpty ? word : currentPageContent + " " + word
            let testHeight = TextHeightMeasurer.calculateHeight(for: testContent, width: geometrySize.width - 32, font: font)
            
            let availableHeight = pages.isEmpty ? availableHeightForFirstPage : availableHeightForOtherPages

            if currentHeight + testHeight > availableHeight {
                if !currentPageContent.isEmpty {
                    pages.append(currentPageContent)
                }
                currentPageContent = word
                currentHeight = TextHeightMeasurer.calculateHeight(for: word, width: geometrySize.width - 32, font: font)
            } else {
                currentPageContent = testContent
                currentHeight = testHeight
            }
        }
        
        if !currentPageContent.isEmpty {
            pages.append(currentPageContent)
        }
        
        return pages
    }
}

// Helper for measuring text height
struct TextHeightMeasurer: UIViewRepresentable {
    let text: String
    let font: UIFont

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = font
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = text
    }

    static func calculateHeight(for text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = font
        label.text = text
        return label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }
}

struct BookReadingView_Previews: PreviewProvider {
    static var previews: some View {
        BookReadingView(
            bookTitle: "万相之王",
            chapterTitle: "第一章 我有三个相宫",
            content: "Your content here..."
        )
    }
}
