import SwiftSoup
import UIKit

enum ParseError: Error {
    case invalidURL
    case noData
    case parsingError
}

struct HTMLParser {

    // Method to parse the HTML and extract the chapter content
    func parseHTML(data: Data) -> Result<String, ParseError> {
        guard let content = String(data: data, encoding: .utf8) else {
            print("HTMLParser: Failed to convert data to string with UTF-8 encoding.")
            return .failure(.parsingError)
        }

        do {
            let doc: Document = try SwiftSoup.parse(content)
            print("HTMLParser: Successfully parsed HTML content.")
            
            // Extract content from <body id="read"><div class="book reader"><div class="content"><div id="chaptercontent">
            let chapterContent = try doc.select("body#read div.book.reader div.content div#chaptercontent").text()
            if chapterContent.isEmpty {
                print("HTMLParser: Chapter content is empty or not found.")
                return .failure(.parsingError)
            }
            
            return .success(chapterContent)
        } catch {
            print("HTMLParser: Error parsing HTML: \(error)")
            return .failure(.parsingError)
        }
    }

    // Method to split the extracted content into pages
    func splitContentIntoPages(content: String, width: CGFloat, height: CGFloat, textStyle: TextStyle) -> [String] {
        var pages: [String] = []
        var currentPageContent = ""
        var currentPageHeight: CGFloat = 0

        let words = content.split(separator: " ")
        for word in words {
            let testContent = currentPageContent.isEmpty ? "\(word)" : "\(currentPageContent) \(word)"
            let textHeight = measureTextHeight(text: testContent, width: width, textStyle: textStyle)

            if currentPageHeight + textHeight > height {
                pages.append(currentPageContent)
                currentPageContent = "\(word)"
                currentPageHeight = measureTextHeight(text: currentPageContent, width: width, textStyle: textStyle)
            } else {
                currentPageContent = testContent
                currentPageHeight += textHeight
            }
        }

        if !currentPageContent.isEmpty {
            pages.append(currentPageContent)
        }

        print("HTMLParser: Parsed \(pages.count) pages.")
        return pages
    }

    // Method to measure the height of a given text based on the current text style and width constraints
    private func measureTextHeight(text: String, width: CGFloat, textStyle: TextStyle) -> CGFloat {
        let constraintRect = CGSize(width: width - 20, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: textStyle.font, .paragraphStyle: textStyle.paragraphStyle], context: nil)
        return ceil(boundingBox.height)
    }
}
