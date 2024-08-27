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
                        VStack(alignment: .leading) {
                            Text(chapterTitle)
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 8)
                            
                            Text(pages[0])
                                .padding(.horizontal)
                                .frame(width: geometry.size.width - 32, alignment: .topLeading)
                            Spacer()
                        }
                        .tag(0)
                        
                        // Additional content pages
                        ForEach(1..<pages.count, id: \.self) { index in
                            VStack(alignment: .leading) {
                                Text(pages[index])
                                    .padding(.horizontal)
                                    .frame(width: geometry.size.width - 32, alignment: .topLeading)
                                Spacer()
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
    
    // Improved content splitting logic with consideration for new-line characters
    func splitIntoPages(content: String, geometrySize: CGSize) -> [String] {
        let font = UIFont.systemFont(ofSize: 17)
        let titleHeight = TextHeightMeasurer.calculateHeight(for: chapterTitle, width: geometrySize.width - 32, font: UIFont.systemFont(ofSize: 24))
        let availableHeightForFirstPage = geometrySize.height - titleHeight - 120 // Adjust for padding and title
        let availableHeightForOtherPages = geometrySize.height - 120 // Adjust for padding

        var pages: [String] = []
        var currentPageContent = ""
        var currentHeight: CGFloat = 0
        
        let characters = Array(content)  // Split the content into individual characters

        print("Starting page splitting...")

        for char in characters {
            let testContent = currentPageContent.isEmpty ? String(char) : currentPageContent + String(char)
            var testHeight = TextHeightMeasurer.calculateHeight(for: testContent, width: geometrySize.width - 32, font: font)
            
            // Adjust height calculation if the content includes new-line characters
            let newLineCount = testContent.filter { $0 == "\n" }.count
            testHeight += CGFloat(newLineCount) * font.lineHeight * 0.3 // Adjust for new-lines without overestimating

            let availableHeight = pages.isEmpty ? availableHeightForFirstPage : availableHeightForOtherPages

            print("Current Page: \(pages.count + 1)")
            print("Attempting to add character: \(char)")
            print("Test content height: \(testHeight), Available height: \(availableHeight), Current height: \(currentHeight)")

            if currentHeight + testHeight > availableHeight {
                if testHeight > availableHeight {
                    print("First content block too large; splitting further...")
                    let splitContent = splitContentRecursively(content: testContent, availableHeight: availableHeight, font: font, width: geometrySize.width - 32)
                    pages.append(contentsOf: splitContent)
                    currentPageContent = ""
                    currentHeight = 0
                } else {
                    print("Page limit reached, creating new page...")
                    pages.append(currentPageContent)
                    currentPageContent = String(char)
                    currentHeight = TextHeightMeasurer.calculateHeight(for: String(char), width: geometrySize.width - 32, font: font)
                    print("New page created, current page height: \(currentHeight)")
                }
            } else {
                currentPageContent = testContent
                currentHeight = testHeight
                print("Content added to current page, new height: \(currentHeight)")
            }
        }
        
        if !currentPageContent.isEmpty {
            pages.append(currentPageContent)
            print("Final page added, contains \(currentPageContent.count) characters")
        }
        
        return pages
    }
    
    // Recursive function to split large content blocks that exceed the available height
    func splitContentRecursively(content: String, availableHeight: CGFloat, font: UIFont, width: CGFloat) -> [String] {
        var splitPages: [String] = []
        var currentContent = ""
        var currentHeight: CGFloat = 0
        let characters = Array(content)  // Split the content into individual characters

        for char in characters {
            let testContent = currentContent.isEmpty ? String(char) : currentContent + String(char)
            var testHeight = TextHeightMeasurer.calculateHeight(for: testContent, width: width, font: font)
            
            // Adjust height calculation if the content includes new-line characters
            let newLineCount = testContent.filter { $0 == "\n" }.count
            testHeight += CGFloat(newLineCount) * font.lineHeight * 0.3 // Adjust for new-lines without overestimating

            if currentHeight + testHeight > availableHeight {
                splitPages.append(currentContent)
                currentContent = String(char)
                currentHeight = TextHeightMeasurer.calculateHeight(for: String(char), width: width, font: font)
            } else {
                currentContent = testContent
                currentHeight = testHeight
            }
        }
        
        if !currentContent.isEmpty {
            splitPages.append(currentContent)
        }
        
        return splitPages
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
