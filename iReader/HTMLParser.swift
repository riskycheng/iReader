import SwiftSoup
import UIKit
import Foundation

enum ParseError: Error {
    case invalidURL
    case noData
    case parsingError
}

struct HTMLParser {
    private var textStyle: TextStyle
    var prevLink: String? = nil
    var nextLink: String? = nil

    init(textStyle: TextStyle) {
        self.textStyle = textStyle
    }

    mutating func parseHTML(data: Data, baseURL: String) -> Result<String, ParseError> {
        guard let content = String(data: data, encoding: .utf8) else {
            print("HTMLParser: Failed to convert data to string with UTF-8 encoding.")
            return .failure(.parsingError)
        }

        do {
            let doc: Document = try SwiftSoup.parse(content)
            print("HTMLParser: Successfully parsed HTML content.")

            // Remove the footer part
            try doc.select("p.readinline").remove()

            // Extract previous and next chapter links and combine with the base URL
            if let prevHref = try doc.select("a#pb_prev").attr("href").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                self.prevLink = baseURL + prevHref
            }
            if let nextHref = try doc.select("a#pb_next").attr("href").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                self.nextLink = baseURL + nextHref
            }
            
            
            print("Prev-link:\(self.prevLink), Next-link:\(self.nextLink)")
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


    // Method to measure the height of a single line of text with the internal text style
    func measureSingleLineHeight() -> CGFloat {
        let label = UILabel()
        label.numberOfLines = 1 // Only measure one line
        label.attributedText = NSAttributedString(string: "Sample Text", attributes: [.font: textStyle.font, .paragraphStyle: createParagraphStyle()])
        let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        return label.sizeThatFits(maxSize).height
    }

    // Method to measure the combined height of a single line of text and two line spaces
    func measureSingleLineWithTwoLineSpacesHeight() -> CGFloat {
        let singleLineHeight = measureSingleLineHeight()
        let res = singleLineHeight * 4
        return res
    }

    // Method to split the extracted content into pages dynamically using internal text style
    func splitContentIntoPages(content: String, width: CGFloat, height: CGFloat) -> [String] {
        var pages: [String] = []
        var remainingContent = content

        while !remainingContent.isEmpty {
            let renderedHeight = measureRenderedHeight(text: remainingContent, width: width)

            if renderedHeight > height {
                let (pageContent, leftoverContent) = splitContentToFitHeight(remainingContent, width: width, maxHeight: height)
                pages.append(pageContent)
                remainingContent = leftoverContent
            } else {
                pages.append(remainingContent)
                remainingContent = ""
            }
        }

        return pages
    }

    // Measure the rendered height of the text using internal text style
    private func measureRenderedHeight(text: String, width: CGFloat) -> CGFloat {
        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = NSAttributedString(string: text, attributes: [.font: textStyle.font, .paragraphStyle: createParagraphStyle()])
        let maxSize = CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude)
        return label.sizeThatFits(maxSize).height
    }

    // Split content into a page that fits within the given height using internal text style
    private func splitContentToFitHeight(_ content: String, width: CGFloat, maxHeight: CGFloat) -> (String, String) {
        var pageContent = ""
        var remainingContent = content
        var testContent = ""

        let words = content.split(separator: " ")
        for word in words {
            testContent = pageContent.isEmpty ? "\(word)" : "\(pageContent) \(word)"
            let renderedHeight = measureRenderedHeight(text: testContent, width: width)

            if renderedHeight > maxHeight {
                break
            } else {
                pageContent = testContent
                remainingContent = String(content.dropFirst(pageContent.count))
            }
        }

        return (pageContent, remainingContent)
    }

    // Create a paragraph style with the internal text style's line spacing
    private func createParagraphStyle() -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = textStyle.lineSpacing
        return paragraphStyle
    }
}
