import Foundation
import SwiftSoup

struct HTMLBookParser {
    static func parseBasicBookInfo(_ html: String, baseURL: String) -> Book? {
        do {
            print("Parsing HTML for basic book info. Base URL: \(baseURL)")
            let document = try SwiftSoup.parse(html)
            
            let title = try document.select("h1.bookTitle").text()
            print("Parsed title: \(title)")
            
            let author = try document.select(".info .small span").first()?.text() ?? "Unknown Author"
            print("Parsed author: \(author)")
            
            let coverURL = try document.select(".info .cover img").first()?.attr("src") ?? ""
            print("Parsed cover URL: \(coverURL)")
            
            let lastUpdated = try document.select(".info .small span.last").first()?.text() ?? "Unknown Date"
            print("Parsed last updated: \(lastUpdated)")
            
            let status = try document.select(".info .small span").get(1).text()
            print("Parsed status: \(status)")
            
            let introduction = try document.select(".intro dl dd").first()?.text() ?? "No Introduction Available"
            print("Parsed introduction: \(introduction.prefix(50))...") // Print first 50 characters
            
            let firstChapterLink = try document.select(".listmain dd a").first()?.attr("href") ?? ""
            let completeFirstChapterLink = baseURL + firstChapterLink
            print("First chapter link: \(completeFirstChapterLink)")
            
            return Book(
                title: title,
                author: author,
                coverURL: coverURL,
                lastUpdated: lastUpdated,
                status: status,
                introduction: introduction,
                chapters: [Book.Chapter(title: "First Chapter", link: completeFirstChapterLink)],
                link: baseURL
            )
        } catch {
            print("Error parsing HTML for basic book info: \(error)")
            return nil
        }
    }
    
    static func parseHTML(_ html: String, baseURL: String) -> Book? {
        do {
            let document = try SwiftSoup.parse(html)
            
            // Parse title
            let title = try document.select("h1.bookTitle").text()
            
            // Parse author
            let authorElement = try document.select(".info .small span").first()
            let author = try authorElement?.text() ?? "Unknown Author"
            
            // Parse cover image URL
            let coverElement = try document.select(".info .cover img").first()
            let coverURL = try coverElement?.attr("src") ?? ""
            
            // Parse last updated date
            let lastUpdatedElement = try document.select(".info .small span.last").first()
            let lastUpdated = try lastUpdatedElement?.text() ?? "Unknown Date"
            
            // Parse status
            let statusElement = try document.select(".info .small span").get(1)
            let status = try statusElement.text()
            
            // Parse introduction
            let introElement = try document.select(".intro dl dd").first()
            let introduction = try introElement?.text() ?? "No Introduction Available"
            
            // Parse chapter list and append baseURL to chapter links
            let chapterElements = try document.select(".listmain dd a")
            let chapters: [Book.Chapter] = try chapterElements.array().map { element in
                let chapterTitle = try element.text()
                let chapterLink = try element.attr("href")
                let completeChapterLink = baseURL + chapterLink
                return Book.Chapter(title: chapterTitle, link: completeChapterLink)
            }
            
            // Create and return the Book object
            return Book(
                title: title,
                author: author,
                coverURL: coverURL,
                lastUpdated: lastUpdated,
                status: status,
                introduction: introduction,
                chapters: chapters,
                link: baseURL
            )
        } catch {
            print("Error parsing HTML: \(error)")
            return nil
        }
    }
    
    static func parseChapterContent(_ html: String, baseURL: String) -> (content: String, prevLink: String?, nextLink: String?)? {
        do {
            let doc: Document = try SwiftSoup.parse(html)
            try doc.select("p.readinline").remove()
            
            let prevHref = try doc.select("a#pb_prev").attr("href")
            let nextHref = try doc.select("a#pb_next").attr("href")
            let prevLink = prevHref.isEmpty ? nil : baseURL + (prevHref.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
            let nextLink = nextHref.isEmpty ? nil : baseURL + (nextHref.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
            
            var chapterContent = try doc.select("body#read div.book.reader div.content div#chaptercontent").html()
            chapterContent = manualHTMLClean(chapterContent)
            
            if chapterContent.isEmpty {
                return nil
            }
            
            return (content: chapterContent, prevLink: prevLink, nextLink: nextLink)
        } catch {
            print("Error parsing chapter HTML: \(error)")
            return nil
        }
    }
    
    private static func manualHTMLClean(_ content: String) -> String {
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
}
