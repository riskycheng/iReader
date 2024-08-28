import SwiftUI

struct BookReadingView: View {
    let bookName: String
    let chapterName: String
    @State private var currentPage: Int = 0
    @State private var logs: String = ""

    private let contentPages: [String]

    init(bookName: String, chapterName: String) {
        self.bookName = bookName
        self.chapterName = chapterName
        
        let screenSize = UIScreen.main.bounds.size
        let font = UIFont.systemFont(ofSize: 18) // Adjust the font size as needed
        let lineSpacing: CGFloat = 4.0 // Adjust line spacing as needed

        // Logging the page split process
        var logMessages = "Starting page split...\n"
        self.contentPages = BookUtils.splitContentIntoPages(
            content: BookContent.fullContent,
            pageSize: CGSize(width: screenSize.width - 40, height: screenSize.height - 150), // Adjusted height to account for title and bottom bar
            font: font,
            lineSpacing: lineSpacing,
            logMessages: &logMessages
        )
        _logs = State(initialValue: logMessages)
    }

    var body: some View {
        ZStack {
            VStack {
                // Top Navigation Bar
                HStack {
                    Text(bookName)
                        .font(.headline)
                    Spacer()
                    Text(chapterName)
                        .font(.headline)
                }
                .padding([.leading, .trailing, .top], 20)
                
                // Content with visible region highlighted
                VStack {
                    Text(contentPages[currentPage])
                        .font(.body)
                        .padding([.leading, .trailing], 20)
                        .background(Color.yellow.opacity(0.3)) // Highlight the visible region
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if value.translation.width < 0 { // Swipe Left to go to next page
                                        goToNextPage()
                                    } else if value.translation.width > 0 { // Swipe Right to go to previous page
                                        goToPreviousPage()
                                    }
                                }
                        )
                }
                
                Spacer()
                
                // Bottom Bar with Battery Status and Page Index
                HStack {
                    // Battery status icon and percentage
                    HStack {
                        Image(systemName: "battery.100")
                        Text("100%")
                            .font(.footnote)
                    }
                    Spacer()
                    // Page indexer
                    Text("\(currentPage + 1)/\(contentPages.count)")
                        .font(.footnote)
                }
                .padding([.leading, .trailing, .bottom], 20)
            }
            .navigationBarHidden(true)
            
            // Overlay the log view on top of everything else
            VStack {
                Spacer()
                LogView(logs: $logs)
                    .frame(height: 150) // Adjust the height of the log view as needed
                    .opacity(0.8) // Adjust the opacity for better visibility
            }
            .padding(.bottom)
        }
    }
    
    // MARK: - Helper Methods
    
    private func goToNextPage() {
        if currentPage < contentPages.count - 1 {
            currentPage += 1
        }
    }
    
    private func goToPreviousPage() {
        if currentPage > 0 {
            currentPage -= 1
        }
    }
}

struct BookReadingView_Previews: PreviewProvider {
    static var previews: some View {
        BookReadingView(bookName: "万相之王", chapterName: "第一章 我有三个相宫")
    }
}
