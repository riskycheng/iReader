import Foundation
import SwiftSoup

struct RankingCategory {
    let name: String
    let books: [RankedBook]
}

struct RankedBook {
    let name: String
    let author: String
    let link: String
}

class HTMLRankingParser {
    static func parseRankings(html: String) -> [RankingCategory] {
        var categories: [RankingCategory] = []
        
        do {
            let doc: Document = try SwiftSoup.parse(html)
            let blocks = try doc.select("div.wrap.rank div.blocks")
            
            for block in blocks {
                let categoryName = try block.select("h2").text()
                var books: [RankedBook] = []
                
                let bookItems = try block.select("ul li")
                for item in bookItems {
                    let linkElement = try item.select("a").first()
                    let bookName = try linkElement?.text() ?? ""
                    let relativeLink = try linkElement?.attr("href") ?? ""
                    let fullLink = "https://www.bqgda.cc" + relativeLink
                    let author = try item.ownText()
                    
                    books.append(RankedBook(name: bookName, author: author, link: fullLink))
                }
                
                categories.append(RankingCategory(name: categoryName, books: books))
            }
        } catch {
            print("解析排行榜时出错: \(error)")
        }
        
        return categories
    }
}