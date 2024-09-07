import Foundation
import SwiftSoup

class HTMLSearchParser {
    static func parseSearchResults(html: String, baseURL: String) -> [Book] {
        print("Starting to parse search results HTML. HTML length: \(html.count)")
        var books: [Book] = []
        
        do {
            let doc: Document = try SwiftSoup.parse(html)
            print("HTML parsed successfully")
            
            let bookboxes: Elements = try doc.select("div.bookbox")
            print("Found \(bookboxes.count) bookboxes")
            
            for (index, bookbox) in bookboxes.enumerated() {
                if let book = parseBookBox(bookbox, baseURL: baseURL) {
                    books.append(book)
                    print("Parsed book \(index + 1): \(book.title)")
                } else {
                    print("Failed to parse book \(index + 1)")
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
            print("Book link: \(bookLink)")
            
            let coverElement: Element = try bookbox.select("img").first() ?? Element(Tag("img"), "")
            let coverURL: String = try coverElement.attr("src")
            print("Cover URL: \(coverURL)")
            
            let bookInfoElement: Element = try bookbox.select("div.bookinfo").first() ?? Element(Tag("div"), "")
            let bookName: String = try bookInfoElement.select("h4.bookname").text()
            print("Book name: \(bookName)")
            
            let author: String = try bookInfoElement.select("div.author").text().replacingOccurrences(of: "作者：", with: "")
            print("Author: \(author)")
            
            let introduction: String = try bookInfoElement.select("div.uptime").text()
            print("Introduction: \(introduction)")
            
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
}
