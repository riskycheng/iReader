import Foundation
import SwiftSoup

struct HTMLBookParser {
    // 添加网站配置常量
    private static let baseDomain = "www.qu08.cc"
    private static let baseURL = "https://\(baseDomain)"
    private static let chapterPathPrefix = "/read"
    
    // 添加辅助方法
    private static func buildChapterURL(path: String) -> String {
        // 移除可能存在的旧路径前缀
        var cleanPath = path
        if cleanPath.hasPrefix("/books") {
            cleanPath = cleanPath.replacingOccurrences(of: "/books", with: "")
        }
        
        // 确保路径以/开头
        if !cleanPath.hasPrefix("/") {
            cleanPath = "/" + cleanPath
        }
        
        // 检查路径是否已经包含 "/read/" 前缀，避免重复
        if cleanPath.hasPrefix(chapterPathPrefix) {
            return "\(baseURL)\(cleanPath)"
        }
        
        return "\(baseURL)\(chapterPathPrefix)\(cleanPath)"
    }
    
    private static func updateURL(_ urlString: String) -> String {
        var updatedURL = urlString
        
        // 替换旧路径前缀
        if updatedURL.contains("/books/") {
            updatedURL = updatedURL.replacingOccurrences(of: "/books/", with: "\(chapterPathPrefix)/")
        }
        
        // 检查是否已经包含 "/read/" 路径，避免重复
        if updatedURL.contains("\(baseURL)\(chapterPathPrefix)/\(chapterPathPrefix)/") {
            updatedURL = updatedURL.replacingOccurrences(of: "\(baseURL)\(chapterPathPrefix)/\(chapterPathPrefix)/", with: "\(baseURL)\(chapterPathPrefix)/")
        }
        
        // 确保使用最新的域名
        if !updatedURL.contains(baseDomain) {
            // 提取路径部分
            if let url = URL(string: updatedURL),
               let host = url.host,
               let pathStart = updatedURL.range(of: host)?.upperBound {
                let path = String(updatedURL[pathStart...])
                updatedURL = "\(baseURL)\(path)"
            }
        }
        
        return updatedURL
    }
    
    static func parseBasicBookInfo(_ html: String, baseURL: String, bookURL: String) -> Book? {
           do {
               let document = try SwiftSoup.parse(html)
               
               // Update the selector for the title
               let title = try document.select("div.info h1").text()
               
               let author = try document.select(".info .small span").first()?.text() ?? "Unknown Author"
               
               let coverURL = try document.select(".info .cover img").first()?.attr("src") ?? ""
               
               let lastUpdated = try document.select(".info .small span.last").first()?.text() ?? "Unknown Date"
               
               let status = try document.select(".info .small span").get(1).text()
               
               let introduction = try document.select(".intro dl dd").first()?.text() ?? "No Introduction Available"
               
               let firstChapterLink = try document.select(".listmain dd a").first()?.attr("href") ?? ""
               let completeFirstChapterLink = buildChapterURL(path: firstChapterLink)
               
               let book = Book(
                   title: title,
                   author: author,
                   coverURL: coverURL,
                   lastUpdated: lastUpdated,
                   status: status,
                   introduction: introduction,
                   chapters: [Book.Chapter(title: "First Chapter", link: completeFirstChapterLink)],
                   link: bookURL
               )
               
               return book
           } catch {
               print("Error parsing HTML for basic book info: \(error)")
               return nil
           }
       }
    
    static func parseHTML(_ html: String, baseURL: String, bookURL: String) -> Book? {
        do {
            let document = try SwiftSoup.parse(html)
            
            // Update the selector for the title
            let title = try document.select("div.info h1").text()
            
            let author = try document.select(".info .small span").first()?.text() ?? "Unknown Author"
            
            let coverURL = try document.select(".info .cover img").first()?.attr("src") ?? ""
            
            let lastUpdated = try document.select(".info .small span.last").first()?.text() ?? "Unknown Date"
            
            let status = try document.select(".info .small span").get(1).text()
            
            let introduction = try document.select(".intro dl dd").first()?.text() ?? "No Introduction Available"
            
            let chapterElements = try document.select(".listmain dd a")
            
            let chapters: [Book.Chapter] = try chapterElements.array().compactMap { element in
                let chapterTitle = try element.text()
                let chapterLink = try element.attr("href")
                
                // Skip if the title contains "展开全部章节"
                guard !chapterTitle.contains("展开全部章节") else {
                    return nil
                }
                
                // 使用本地方法构建链接
                let completeChapterLink = buildChapterURL(path: chapterLink)
                
                return Book.Chapter(title: chapterTitle, link: completeChapterLink)
            }
            
            let book = Book(
                title: title,
                author: author,
                coverURL: coverURL,
                lastUpdated: lastUpdated,
                status: status,
                introduction: introduction,
                chapters: chapters,
                link: bookURL
            )
            
            return book
        } catch {
            print("Error parsing HTML for full book info: \(error)")
            return nil
        }
    }
    
    static func parseChapterContent(_ html: String, baseURL: String) -> (content: String, prevLink: String?, nextLink: String?)? {
        do {
            let doc: Document = try SwiftSoup.parse(html)
            try doc.select("p.readinline").remove()
            
            let prevHref = try doc.select("a#pb_prev").attr("href")
            let nextHref = try doc.select("a#pb_next").attr("href")
            
            // 使用本地方法更新链接
            let prevLink = prevHref.isEmpty ? nil : buildChapterURL(path: prevHref)
            let nextLink = nextHref.isEmpty ? nil : buildChapterURL(path: nextHref)
            
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
