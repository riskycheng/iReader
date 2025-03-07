import Foundation
import SwiftSoup

struct RankingCategory: Equatable {
    let name: String
    let books: [RankedBook]
    
    static func == (lhs: RankingCategory, rhs: RankingCategory) -> Bool {
        return lhs.name == rhs.name && lhs.books == rhs.books
    }
}

struct RankedBook: Equatable {
    let name: String
    let author: String
    let link: String
    let coverURL: String?
    
    static func == (lhs: RankedBook, rhs: RankedBook) -> Bool {
        return lhs.name == rhs.name && lhs.author == rhs.author && lhs.link == rhs.link && lhs.coverURL == rhs.coverURL
    }
}

class HTMLRankingParser {
    // 添加网站配置常量
    private static let baseDomain = "www.qu08.cc"
    private static let baseURL = "https://\(baseDomain)"
    private static let bookPathPrefix = "/read"
    
    // 添加辅助方法
    private static func buildBookURL(path: String) -> String {
        // 移除可能存在的旧路径前缀
        var cleanPath = path
        if cleanPath.hasPrefix("/books") {
            cleanPath = cleanPath.replacingOccurrences(of: "/books", with: "")
        }
        
        // 确保路径以/开头
        if !cleanPath.hasPrefix("/") {
            cleanPath = "/" + cleanPath
        }
        
        return "\(baseURL)\(bookPathPrefix)\(cleanPath)"
    }
    
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
                    // 使用本地方法构建完整链接
                    let fullLink = buildBookURL(path: relativeLink)
                    let author = try item.ownText()
                    
                    // 尝试提取封面图片 URL
                    let coverElement = try item.select("img").first()
                    let coverURL = try coverElement?.attr("src")
                    
                    books.append(RankedBook(name: bookName, author: author, link: fullLink, coverURL: coverURL))
                }
                
                categories.append(RankingCategory(name: categoryName, books: books))
            }
        } catch {
            print("解析排行榜时出错: \(error)")
        }
        
        return categories
    }
}