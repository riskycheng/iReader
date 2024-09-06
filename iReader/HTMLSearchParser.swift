import Foundation
import SwiftSoup

class HTMLSearchParser {
    static func parseSearchResults(html: String, baseURL: String) -> [Book] {
        print("Starting to parse search results HTML")
        var books: [Book] = []
        
        do {
            let doc: Document = try SwiftSoup.parse(html)
            print("HTML parsed successfully")
            
            // Check for dynamically loaded content
            let bookboxes: Elements = try doc.select("div.bookbox")
            if !bookboxes.isEmpty() {
                for bookbox in bookboxes {
                    if let book = parseBookBox(bookbox, baseURL: baseURL) {
                        books.append(book)
                    }
                }
            } else {
                // If no bookboxes found, try to extract data from JavaScript
                let scripts: Elements = try doc.select("script")
                for script in scripts {
                    let scriptContent = try script.html()
                    if scriptContent.contains("loadmore") {
                        if let extractedData = extractDataFromScript(scriptContent) {
                            books = extractedData
                            break
                        }
                    }
                }
            }
        } catch {
            print("Error parsing HTML: \(error)")
        }
        
        print("Finished parsing. Found \(books.count) books.")
        return books
    }
    
    private static func parseBookBox(_ bookbox: Element, baseURL: String) -> Book? {
        do {
            let linkElement: Element = try bookbox.select("a").first() ?? Element(Tag("a"), "")
            let bookLink: String = try baseURL + linkElement.attr("href")
            
            let coverElement: Element = try bookbox.select("img").first() ?? Element(Tag("img"), "")
            let coverURL: String = try coverElement.attr("src")
            
            let bookInfoElement: Element = try bookbox.select("div.bookinfo").first() ?? Element(Tag("div"), "")
            let bookName: String = try bookInfoElement.select("h4.bookname").text()
            let author: String = try bookInfoElement.select("div.author").text()
            let introduction: String = try bookInfoElement.select("div.uptime").text()
            
            return Book(
                title: bookName,
                author: author,
                coverURL: coverURL,
                lastUpdated: "",
                status: "",
                introduction: introduction,
                chapters: [],
                link: bookLink
            )
        } catch {
            print("Error parsing individual book: \(error)")
            return nil
        }
    }
    
    private static func extractDataFromScript(_ script: String) -> [Book]? {
        // This is a simplified version. You might need to adjust based on the actual script content
        let pattern = "strHtml \\+= '(.+?)'"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let matches = regex?.matches(in: script, options: [], range: NSRange(script.startIndex..., in: script))
        
        var books: [Book] = []
        
        matches?.forEach { match in
            if let range = Range(match.range(at: 1), in: script) {
                let htmlString = String(script[range])
                if let book = parseBookHTML(htmlString) {
                    books.append(book)
                }
            }
        }
        
        return books.isEmpty ? nil : books
    }
    
    private static func parseBookHTML(_ html: String) -> Book? {
        // This is a simplified parser. You might need to adjust based on the actual HTML structure
        do {
            let doc: Document = try SwiftSoup.parse(html)
            let title = try doc.select("h4.bookname a").text()
            let author = try doc.select("div.author").text().replacingOccurrences(of: "作者：", with: "")
            let intro = try doc.select("div.uptime").text()
            let coverURL = try doc.select("img").attr("src")
            let bookLink = try doc.select("h4.bookname a").attr("href")
            
            return Book(
                title: title,
                author: author,
                coverURL: coverURL,
                lastUpdated: "",
                status: "",
                introduction: intro,
                chapters: [],
                link: bookLink
            )
        } catch {
            print("Error parsing book HTML: \(error)")
            return nil
        }
    }
}
