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
                        // First page with fixed title height and content below
                        VStack(alignment: .leading) {
                            HStack {
                                Text(chapterTitle)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .frame(height: 100) // Fixed title height
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 20) // Align left with 20 points margin
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(height: 100)
                            .padding(.bottom, 8)
                            
                            Text(pages[0])
                                .font(.system(size: 17))
                                .lineSpacing(4)
                                .padding(.horizontal, 20)
                                .frame(width: geometry.size.width, alignment: .topLeading)
                            Spacer()
                        }
                        .tag(0)
                        
                        // Additional content pages
                        ForEach(1..<pages.count, id: \.self) { index in
                            VStack(alignment: .leading) {
                                Text(pages[index])
                                    .font(.system(size: 17))
                                    .lineSpacing(4)
                                    .padding(.horizontal, 20) // 20 points left and right margin
                                    .frame(width: geometry.size.width - 40, alignment: .topLeading)
                                Spacer()
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                } else {
                    Text("Loading content...")
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
                .frame(height: 50) // Matching toolbar height
            }
            .onAppear {
                UIDevice.current.isBatteryMonitoringEnabled = true
                self.batteryLevel = UIDevice.current.batteryLevel
                self.pages = splitIntoPages(content: content, geometrySize: geometry.size)
            }
        }
        .onDisappear {
            UIDevice.current.isBatteryMonitoringEnabled = false
        }
    }
    
    
    
    
    
    
    
    
    // Character-based content splitting logic to ensure no truncation
    func splitIntoPages(content: String, geometrySize: CGSize) -> [String] {
        let fontSize: CGFloat = 17
        let font = UIFont.systemFont(ofSize: fontSize)
        let lineSpacing: CGFloat = 8 // Increased line spacing
        let horizontalPadding: CGFloat = 40 // 20 points on each side
        let verticalPadding: CGFloat = 20
        let titleHeight: CGFloat = 100
        let footerHeight: CGFloat = 50
        let titlePaddingContent: CGFloat = 8
        let safetyMargin: CGFloat = 30 // Increased safety margin

        let scaleFactor = min(geometrySize.width / 390, geometrySize.height / 844) // Base on iPhone 14 Pro
        let scaledFontSize = fontSize * scaleFactor
        let scaledLineSpacing = lineSpacing * scaleFactor

        let availableWidthForText = geometrySize.width - horizontalPadding
        let availableHeightForFirstPage = geometrySize.height - titleHeight - footerHeight - verticalPadding - titlePaddingContent - safetyMargin
        let availableHeightForOtherPages = geometrySize.height - footerHeight - (verticalPadding * 2) - safetyMargin

        let paragraphs = content.components(separatedBy: .newlines)
        var pages: [String] = []
        var currentPageContent = ""
        var currentPageHeight: CGFloat = 0
        var isFirstPage = true

        func textHeight(for text: String) -> CGFloat {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: scaledFontSize),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = scaledLineSpacing
                    return style
                }()
            ]
            let boundingRect = (text as NSString).boundingRect(
                with: CGSize(width: availableWidthForText, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            return ceil(boundingRect.height)
        }

        func addPage(_ content: String) {
            pages.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
            currentPageContent = ""
            currentPageHeight = 0
            isFirstPage = false
        }

        for paragraph in paragraphs {
            let paragraphHeight = textHeight(for: paragraph)
            let availableHeight = isFirstPage ? availableHeightForFirstPage : availableHeightForOtherPages
            
            if currentPageHeight + paragraphHeight > availableHeight {
                addPage(currentPageContent)
            }
            
            if !currentPageContent.isEmpty {
                currentPageContent += "\n"
                currentPageHeight += scaledLineSpacing // Add extra space between paragraphs
            }
            currentPageContent += paragraph
            currentPageHeight += paragraphHeight
        }
        
        if !currentPageContent.isEmpty {
            addPage(currentPageContent)
        }

        return pages
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    // Function to calculate text height using UIKit with consistent font and line spacing
    func calculateHeight(for text: String, font: UIFont, width: CGFloat, lineSpacing: CGFloat) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: attributes,
            context: nil
        )
        
        return ceil(boundingRect.height)
    }
}

struct BookReadingView_Previews: PreviewProvider {
    static var previews: some View {
        BookReadingView(
            bookTitle: "万相之王",
            chapterTitle: "第一章 我有三个相宫",
            content: BookContent.fullContent
        )
    }
}
