import SwiftUI

struct BookReadingView: View {
    let bookName: String
    let chapterName: String
    let screenSize: CGSize
    @State private var currentPage: Int = 0
    @State private var logs: String = ""

    private let contentPages: [String]

    init(bookName: String, chapterName: String) {
        self.bookName = bookName
        self.chapterName = chapterName
        
        self.screenSize = UIScreen.main.bounds.size
        
        let font = UIFont.systemFont(ofSize: 18) // Adjust the font size as needed
        let lineSpacing: CGFloat = 4.0 // Adjust line spacing as needed
        
        let visibleHeight: CGFloat = screenSize.height

        // Page split process with logging
        let (pages, logMessages) = BookUtils.splitContentIntoPages(
            content: BookContent.fullContent,
            pageSize: CGSize(width: screenSize.width - 40, height: visibleHeight), // Adjusted height for visible region
            font: font,
            lineSpacing: lineSpacing
        )
        
        self.contentPages = pages
        _logs = State(initialValue: logMessages) // Set the logs to be displayed
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    Text(bookName)
                        .font(.headline)
                    Spacer()
                    Text(chapterName)
                        .font(.headline)
                }
                .padding([.leading, .trailing, .top], 20)
                .background(Color.white)
                .frame(height: 60) // Adjust height as needed
                
                // Content with visible region highlighted
                VStack {
                    Text(contentPages[currentPage])
                        .font(.body)
                        .padding([.leading, .trailing], 20)
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
                .frame(height: screenSize.height - 110) // Ensure the height of the visible region is consistent (60 + 50)
                .background(Color.yellow.opacity(0.3)) // Apply background color to the whole visible region
                
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
                .padding([.leading, .trailing, .vertical], 10) // Adjust padding to match the top toolbar
                .background(Color.white)
                .frame(height: 50) // Adjust height to match top toolbar
            }
            .navigationBarHidden(true)
            
            // Overlay the log view on top of everything else
            VStack {
                Spacer()
                LogView(logs: $logs)
                    .frame(height: 200) // Consistent height for the log view
                    .background(Color.black.opacity(0.2))
                    .foregroundColor(.white)
                    .padding(.bottom, 200)
                    .opacity(0.8) // Adjust the opacity for better visibility
            }
        }
        .ignoresSafeArea(.all)
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
