import SwiftSoup
import UIKit
import Foundation

enum ParseError: Error {
    case invalidURL
    case noData
    case parsingError
}

struct HTMLParser {
    func parseHTML(data: Data, baseURL: String, width: CGFloat, availableHeight: CGFloat, selectedFont: UIFont, selectedFontSize: CGFloat, lineSpacing: CGFloat) -> Result<Article, ParseError> {
        guard let content = String(data: data, encoding: .utf8) else {
            return .failure(.parsingError)
        }
        
        do {
            let doc: Document = try SwiftSoup.parse(content)
            try doc.select("p.readinline").remove()
            
            let title = try doc.title()
            let prevHref = try doc.select("a#pb_prev").attr("href")
            let nextHref = try doc.select("a#pb_next").attr("href")
            let prevLink = prevHref.isEmpty ? nil : baseURL + (prevHref.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
            let nextLink = nextHref.isEmpty ? nil : baseURL + (nextHref.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
            
            var chapterContent = try doc.select("body#read div.book.reader div.content div#chaptercontent").html()
            chapterContent = manualHTMLClean(chapterContent)
            
            if chapterContent.isEmpty {
                return .failure(.parsingError)
            }
            
            let splitPages = splitContentIntoPages(
                content: chapterContent,
                title: title,
                width: width,
                availableHeight: availableHeight,
                selectedFont: selectedFont,
                selectedFontSize: selectedFontSize,
                lineSpacing: lineSpacing
            )
            
            let article = Article(
                title: title,
                totalContent: chapterContent,
                splitPages: splitPages,
                prevLink: prevLink,
                nextLink: nextLink
            )
            return .success(article)
            
        } catch {
            return .failure(.parsingError)
        }
    }
    
    private func manualHTMLClean(_ content: String) -> String {
        var cleanedContent = content
        cleanedContent = cleanedContent.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        cleanedContent = cleanedContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        cleanedContent = cleanedContent.replacingOccurrences(of: "&nbsp;", with: " ")
        cleanedContent = cleanedContent.replacingOccurrences(of: "&lt;", with: "<")
        cleanedContent = cleanedContent.replacingOccurrences(of: "&gt;", with: ">")
        cleanedContent = cleanedContent.replacingOccurrences(of: "&amp;", with: "&")
        cleanedContent = cleanedContent.replacingOccurrences(of: "&quot;", with: "\"")
        cleanedContent = cleanedContent.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func splitContentIntoPages(content: String, title: String, width: CGFloat, availableHeight: CGFloat, selectedFont: UIFont, selectedFontSize: CGFloat, lineSpacing: CGFloat) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        let titleHeight = measureRenderedHeight(text: title, width: width, isTitle: true, selectedFont: selectedFont, selectedFontSize: selectedFontSize, lineSpacing: lineSpacing)
        
        var pages: [String] = []
        var currentPage = ""
        var currentPageHeight: CGFloat = 0
        var isFirstPage = true
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let lineHeight = measureRenderedHeight(text: line, width: width, isTitle: false, selectedFont: selectedFont, selectedFontSize: selectedFontSize, lineSpacing: lineSpacing)
            
            if isFirstPage && currentPageHeight == 0 {
                currentPageHeight += titleHeight
            }
            
            if currentPageHeight + lineHeight > availableHeight && !currentPage.isEmpty {
                pages.append(currentPage.trimmingCharacters(in: .whitespacesAndNewlines))
                currentPage = ""
                currentPageHeight = 0
                isFirstPage = false
            }
            
            currentPage += line + "\n"
            currentPageHeight += lineHeight
            
            let recalculatedHeight = measureRenderedHeight(text: currentPage, width: width, isTitle: false, selectedFont: selectedFont, selectedFontSize: selectedFontSize, lineSpacing: lineSpacing)
            
            if recalculatedHeight > availableHeight {
                pages.append(currentPage.trimmingCharacters(in: .whitespacesAndNewlines))
                currentPage = ""
                currentPageHeight = 0
            }
        }
        
        if !currentPage.isEmpty {
            pages.append(currentPage.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return pages
    }
    
    private func measureRenderedHeight(text: String, width: CGFloat, isTitle: Bool = false, selectedFont: UIFont, selectedFontSize: CGFloat, lineSpacing: CGFloat) -> CGFloat {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = isTitle ? UIFont.systemFont(ofSize: 28, weight: .bold) : selectedFont.withSize(selectedFontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: label.font!,
            .paragraphStyle: paragraphStyle
        ])
        let maxSize = CGSize(width: width - 40, height: .greatestFiniteMagnitude)
        return label.sizeThatFits(maxSize).height + 5
    }
}
