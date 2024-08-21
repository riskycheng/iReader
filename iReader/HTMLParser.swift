import SwiftSoup
import UIKit
import Foundation

enum ParseError: Error {
    case invalidURL
    case noData
    case parsingError
}

struct HTMLParser {
    
    func parseHTML(data: Data, baseURL: String, width: CGFloat, height: CGFloat) -> Result<Article, ParseError> {
        guard let content = String(data: data, encoding: .utf8) else {
            print("HTMLParser: Failed to convert data to string with UTF-8 encoding.")
            return .failure(.parsingError)
        }
        
        do {
            let doc: Document = try SwiftSoup.parse(content)
            print("HTMLParser: Successfully parsed HTML content.")
            
            // Remove the footer part
            try doc.select("p.readinline").remove()
            
            // Extract the title
            let title = try doc.title()
            print("HTMLParser: Extracted Title: \(title)")
            
            // Calculate the height taken by the title
            let titleHeight = measureRenderedHeight(text: title, width: width)
            
            // Extract previous and next chapter links and combine them with the base URL
            let prevHref = try doc.select("a#pb_prev").attr("href")
            let nextHref = try doc.select("a#pb_next").attr("href")
            let prevLink = prevHref.isEmpty ? nil : baseURL + (prevHref.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
            let nextLink = nextHref.isEmpty ? nil : baseURL + (nextHref.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
            
            // Extract content from <body id="read"><div class="book reader"><div class="content"><div id="chaptercontent">
            var chapterContent = try doc.select("body#read div.book.reader div.content div#chaptercontent").html()
//            print("HTMLParser: Original HTML Content: \(chapterContent)")
            

            // Clean up other HTML tags manually without stripping the new-lines
            chapterContent = manualHTMLClean(chapterContent)
//            print("HTMLParser: Cleaned content after manual HTML cleaning: \(chapterContent)")
            
            
            if chapterContent.isEmpty {
                print("HTMLParser: Chapter content is empty or not found.")
                return .failure(.parsingError)
            }
            
            // Split the content into pages, accounting for the title height on the first page
            let splitPages = splitContentIntoPages(content: chapterContent, width: width, height: height, titleHeight: titleHeight)
            
            
            // Create and return the Article object
            let article = Article(
                title: title,
                totalContent: chapterContent,
                splitPages: splitPages,
                prevLink: prevLink,
                nextLink: nextLink
            )
            return .success(article)
            
        } catch {
            print("HTMLParser: Error parsing HTML: \(error)")
            return .failure(.parsingError)
        }
    }
    
    // Measure the height of a single line of text using the system-default font and line spacing
    func measureSingleLineHeight() -> CGFloat {
        var height: CGFloat = 0
        DispatchQueue.main.sync {
            let label = UILabel()
            label.numberOfLines = 1 // Only measure one line
            label.font = UIFont.systemFont(ofSize: 17) // System default font size
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4 // System default line spacing
            if let font = label.font {
                label.attributedText = NSAttributedString(string: "Sample Text", attributes: [
                    .font: font,
                    .paragraphStyle: paragraphStyle
                ])
            }
            let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            height = label.sizeThatFits(maxSize).height
        }
        return height
    }
    
    // Measure the combined height of a single line of text and two line spaces using the system-default settings
    func measureSingleLineWithTwoLineSpacesHeight() -> CGFloat {
        let singleLineHeight = measureSingleLineHeight()
        let res = singleLineHeight * 4
        return res
    }
    
    // The method to split content, considering the height offset for the first page
    private func splitContentIntoPages(content: String, width: CGFloat, height: CGFloat, titleHeight: CGFloat) -> [String] {
        var pages: [String] = []
        var remainingContent = content
        var currentPageHeight = height - titleHeight // Adjust the first page height for the title
        
        while !remainingContent.isEmpty {
            let renderedHeight = measureRenderedHeight(text: remainingContent, width: width)
            
            if renderedHeight > currentPageHeight {
                let (pageContent, leftoverContent) = splitContentToFitHeight(remainingContent, width: width, maxHeight: currentPageHeight)
                pages.append(pageContent)
                remainingContent = leftoverContent
                currentPageHeight = height // Reset for subsequent pages
            } else {
                pages.append(remainingContent)
                remainingContent = ""
            }
        }
        
        print("HTMLParser: Generated \(pages.count) pages.")
        return pages
    }

    // Manually clean HTML while preserving newlines
    private func manualHTMLClean(_ content: String) -> String {
        var cleanedContent = content
        
        // Replace <br>, <br/> or <br /> with a new-line character without depending on spaces
        cleanedContent = cleanedContent.replacingOccurrences(of: "<br", with: "")
        cleanedContent = cleanedContent.replacingOccurrences(of: "/>", with: "")

        return cleanedContent
    }
    
    // Measure the rendered height of the text using system-default font and line spacing
    private func measureRenderedHeight(text: String, width: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        DispatchQueue.main.sync {
            let label = UILabel()
            label.numberOfLines = 0
            label.font = UIFont.systemFont(ofSize: 17) // System default font size
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4 // System default line spacing
            if let font = label.font {
                label.attributedText = NSAttributedString(string: text, attributes: [
                    .font: font,
                    .paragraphStyle: paragraphStyle
                ])
            }
            let maxSize = CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude)
            height = label.sizeThatFits(maxSize).height
        }
        return height
    }
    
    // Split content into a page that fits within the given height using system-default font and line spacing
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
}
