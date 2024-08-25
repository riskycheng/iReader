import SwiftSoup
import UIKit
import Foundation

enum ParseError: Error {
    case invalidURL
    case noData
    case parsingError
}

struct HTMLParser {
    func parseHTML(data: Data, baseURL: String, width: CGFloat, height: CGFloat, toolbarHeight: CGFloat, bottomToolbarHeight: CGFloat, tabViewHeight: CGFloat) -> Result<Article, ParseError> {
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
            
            let splitPages = splitContentIntoPages(content: chapterContent, title: title, width: width, height: height, toolbarHeight: toolbarHeight, bottomToolbarHeight: bottomToolbarHeight, tabViewHeight: tabViewHeight)
            
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
    
    private func splitContentIntoPages(content: String, title: String, width: CGFloat, height: CGFloat, toolbarHeight: CGFloat, bottomToolbarHeight: CGFloat, tabViewHeight: CGFloat) -> [String] {
        let paragraphs = content.components(separatedBy: "\n\n")
        
        // Calculate the available page height considering toolbars and tab view
        let availablePageHeight = height - toolbarHeight - bottomToolbarHeight - tabViewHeight - 40 // Additional padding
        let titleHeight = measureRenderedHeight(text: title, width: width, isTitle: true)
        
        var pages: [String] = []
        var currentPage = ""
        var currentPageHeight: CGFloat = 0
        var isFirstPage = true
        
        for paragraph in paragraphs {
            let paragraphHeight = measureRenderedHeight(text: paragraph, width: width)
            
            if isFirstPage && currentPageHeight == 0 {
                currentPageHeight += titleHeight
            }
            
            if currentPageHeight + paragraphHeight > availablePageHeight && !currentPage.isEmpty {
                pages.append(currentPage.trimmingCharacters(in: .whitespacesAndNewlines))
                currentPage = ""
                currentPageHeight = 0
                isFirstPage = false
            }
            
            currentPage += paragraph + "\n\n"
            currentPageHeight += paragraphHeight
        }
        
        if !currentPage.isEmpty {
            pages.append(currentPage.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return pages
    }
    
    private func measureRenderedHeight(text: String, width: CGFloat, isTitle: Bool = false) -> CGFloat {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = isTitle ? UIFont.systemFont(ofSize: 28, weight: .bold) : UIFont.systemFont(ofSize: 17)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: label.font!,
            .paragraphStyle: paragraphStyle
        ])
        let maxSize = CGSize(width: width - 40, height: .greatestFiniteMagnitude)
        return label.sizeThatFits(maxSize).height + 5
    }
}
