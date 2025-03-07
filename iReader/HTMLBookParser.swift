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
               print("Parsing HTML for basic book info.")
               print("Base URL: \(baseURL)")
               print("Book URL: \(bookURL)")
               
               let document = try SwiftSoup.parse(html)
               
               // Update the selector for the title
               let title = try document.select("div.info h1").text()
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
               let completeFirstChapterLink = buildChapterURL(path: firstChapterLink)
               print("First chapter link: \(completeFirstChapterLink)")
               
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
               
               print("Parsed book:")
               print("Title: \(book.title)")
               print("Author: \(book.author)")
               print("Cover URL: \(book.coverURL)")
               print("Last Updated: \(book.lastUpdated)")
               print("Status: \(book.status)")
               print("Introduction: \(book.introduction.prefix(50))...")
               print("Book Link: \(book.link)")
               print("Number of Chapters: \(book.chapters.count)")
               if let firstChapter = book.chapters.first {
                   print("First Chapter Title: \(firstChapter.title)")
                   print("First Chapter Link: \(firstChapter.link)")
               }
               
               return book
           } catch {
               print("Error parsing HTML for basic book info: \(error)")
               return nil
           }
       }
    
    static func parseHTML(_ html: String, baseURL: String, bookURL: String) -> Book? {
        do {
            print("Parsing HTML for full book info.")
            print("Base URL: \(baseURL)")
            print("Book URL: \(bookURL)")
            
            let document = try SwiftSoup.parse(html)
            
            // Update the selector for the title
            let title = try document.select("div.info h1").text()
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
            
          
            
          
            let chapterElements = try document.select(".listmain dd a")
            var chapterIndex = 0 // 添加一个索引计数器
            
            let chapters: [Book.Chapter] = try chapterElements.array().compactMap { element in
                let chapterTitle = try element.text()
                let chapterLink = try element.attr("href")
                
                // Skip if the title contains "展开全部章节"
                guard !chapterTitle.contains("展开全部章节") else {
                    print("Skipped 'Expand All Chapters' element: \(chapterTitle)")
                    return nil
                }
                
                // 使用本地方法构建链接
                let completeChapterLink = buildChapterURL(path: chapterLink)
                
                // 打印前20章的链接信息
                if chapterIndex < 20 {
                    print("\(chapterIndex + 1). \(chapterTitle)")
                    print("   链接: \(completeChapterLink)\n")
                }
                chapterIndex += 1
                
                return Book.Chapter(title: chapterTitle, link: completeChapterLink)
            }
            print("Parsed \(chapters.count) chapters")

            // 打印章节汇总信息
            print("\n=== 章节信息汇总 ===")
            if let firstChapter = chapters.first {
                print("第一章:")
                print("  标题: \(firstChapter.title)")
                print("  链接: \(firstChapter.link)")
            }
            if let lastChapter = chapters.last {
                print("\n最后一章:")
                print("  标题: \(lastChapter.title)")
                print("  链接: \(lastChapter.link)")
            }
            print("\n有效章节总数: \(chapters.count)")
            print("===================\n")
            
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
