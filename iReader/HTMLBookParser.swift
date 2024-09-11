import Foundation
import SwiftSoup

struct HTMLBookParser {
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
               let completeFirstChapterLink = baseURL + (firstChapterLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
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
            let chapters: [Book.Chapter] = try chapterElements.array().compactMap { element in
                let chapterTitle = try element.text()
                let chapterLink = try element.attr("href")
                
                // Skip if the title contains "展开全部章节"
                guard !chapterTitle.contains("展开全部章节") else {
                    print("Skipped 'Expand All Chapters' element: \(chapterTitle)")
                    return nil
                }
                
                let completeChapterLink = baseURL + (chapterLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
                return Book.Chapter(title: chapterTitle, link: completeChapterLink)
            }
            print("Parsed \(chapters.count) chapters")

            // Print the first 20 chapter items
            print("\nFirst 20 chapters:")
            for (index, chapter) in chapters.prefix(20).enumerated() {
                print("\(index + 1). \(chapter.title)")
            }
            
            
            
            
            
            
            let book = Book(
                title: title,
                author: author,
                coverURL: coverURL,
                lastUpdated: lastUpdated,
                status: status,
                introduction: introduction,
                chapters: chapters,
                link: bookURL  // Use the provided bookURL as the book's link
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
            if let lastChapter = book.chapters.last {
                print("Last Chapter Title: \(lastChapter.title)")
                print("Last Chapter Link: \(lastChapter.link)")
            }
            
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
