import Foundation
import SwiftSoup

class HTMLSearchParser {
    static func parseSearchResults(html: String, baseURL: String, update: @escaping ([Book]) -> Void, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let doc: Document = try SwiftSoup.parse(html)
                let bookElements: Elements = try doc.select("div.bookbox")
                var books: [Book] = []
                
                for element in bookElements {
                    if let book = parseBookBox(element, baseURL: baseURL) {
                        books.append(book)
                    }
                }
                
                DispatchQueue.main.async {
                    update(books)
                    completion()
                }
            } catch {
                print("解析HTML时出错: \(error)")
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    private static func parseBookBox(_ bookbox: Element, baseURL: String) -> Book? {
        do {
            let linkElement: Element = try bookbox.select("a").first() ?? Element(Tag("a"), "")
            let bookLink: String = try baseURL + linkElement.attr("href")
            
            let coverElement: Element = try bookbox.select("img").first() ?? Element(Tag("img"), "")
            let coverURL: String = try coverElement.attr("src")
            
            let bookInfoElement: Element = try bookbox.select("div.bookinfo").first() ?? Element(Tag("div"), "")
            let bookName: String = try bookInfoElement.select("h4.bookname").text()
            
            let author: String = try bookInfoElement.select("div.author").text().replacingOccurrences(of: "作者：", with: "")
            
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
}
