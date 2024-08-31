import Foundation
import SwiftSoup

struct Book: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let author: String
    let coverURL: String
    let lastUpdated: String
    let status: String
    let introduction: String
    let chapters: [Chapter]
    let link: String
    var bookmarks: [Bookmark]
    
    struct Chapter: Codable, Hashable {
        let title: String
        let link: String
    }
    
    struct Bookmark: Identifiable, Hashable, Codable {
        let id: UUID
        let chapterIndex: Int
        let pageIndex: Int
        let text: String
    }
    
    init(id: UUID = UUID(), title: String, author: String, coverURL: String, lastUpdated: String, status: String, introduction: String, chapters: [Chapter], link: String, bookmarks: [Bookmark] = []) {
        self.id = id
        self.title = title
        self.author = author
        self.coverURL = coverURL
        self.lastUpdated = lastUpdated
        self.status = status
        self.introduction = introduction
        self.chapters = chapters
        self.link = link
        self.bookmarks = bookmarks
    }
    
    static func parse(from url: URL, baseURL: String) async throws -> Book {
        print("Parsing book from URL: \(url)")
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            print("Failed to convert data to string")
            throw NSError(domain: "BookParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to convert data to string"])
        }
        
        let doc: Document = try SwiftSoup.parse(html)
        
        let title = try doc.select("h1.bookTitle").text()
        print("Parsed title: \(title)")
        
        let author = try doc.select("div.bookInfo span.author").text()
        print("Parsed author: \(author)")
        
        let coverURL = try doc.select("div.bookImg img").attr("src")
        print("Parsed coverURL: \(coverURL)")
        
        let lastUpdated = try doc.select("div.bookInfo span:contains(最后更新)").text()
        print("Parsed lastUpdated: \(lastUpdated)")
        
        let status = try doc.select("div.bookInfo span:contains(状态)").text()
        print("Parsed status: \(status)")
        
        let introduction = try doc.select("div.bookIntro").text()
        print("Parsed introduction: \(introduction)")
        
        let chapterElements = try doc.select("div.listmain dd a")
        let chapters = try chapterElements.array().map { element -> Chapter in
            let chapterTitle = try element.text()
            let chapterLink = try element.attr("href")
            return Chapter(title: chapterTitle, link: baseURL + chapterLink)
        }
        print("Parsed \(chapters.count) chapters")
        
        let book = Book(
            title: title,
            author: author,
            coverURL: coverURL,
            lastUpdated: lastUpdated,
            status: status,
            introduction: introduction,
            chapters: chapters,
            link: url.absoluteString
        )
        
        print("Parsed book: \(book)")
        return book
    }
    
    mutating func addBookmark(chapterIndex: Int, pageIndex: Int, text: String) {
        let bookmark = Bookmark(id: UUID(), chapterIndex: chapterIndex, pageIndex: pageIndex, text: text)
        bookmarks.append(bookmark)
    }
    
    mutating func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
    }
}

extension Book {
    static func == (lhs: Book, rhs: Book) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.author == rhs.author &&
               lhs.coverURL == rhs.coverURL &&
               lhs.lastUpdated == rhs.lastUpdated &&
               lhs.status == rhs.status &&
               lhs.introduction == rhs.introduction &&
               lhs.chapters == rhs.chapters &&
               lhs.link == rhs.link &&
               lhs.bookmarks == rhs.bookmarks
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(author)
        hasher.combine(coverURL)
        hasher.combine(lastUpdated)
        hasher.combine(status)
        hasher.combine(introduction)
        hasher.combine(chapters)
        hasher.combine(link)
        hasher.combine(bookmarks)
    }
}
