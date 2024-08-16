import Foundation

struct Book: Identifiable, Hashable, Equatable {
    var id = UUID() // Automatically generates a unique identifier for each book
    var title: String
    var author: String
    var coverURL: String
    var lastUpdated: String
    var status: String
    var introduction: String
    var chapters: [(title: String, link: String)]
    var link: String
    
    // Conformance to Equatable
    static func == (lhs: Book, rhs: Book) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.author == rhs.author &&
               lhs.coverURL == rhs.coverURL &&
               lhs.lastUpdated == rhs.lastUpdated &&
               lhs.status == rhs.status &&
               lhs.introduction == rhs.introduction &&
               lhs.chapters.elementsEqual(rhs.chapters) { (lhsChapter, rhsChapter) in
                   return lhsChapter.title == rhsChapter.title && lhsChapter.link == rhsChapter.link
               } &&
               lhs.link == rhs.link
    }
    
    // Conformance to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(author)
        hasher.combine(coverURL)
        hasher.combine(lastUpdated)
        hasher.combine(status)
        hasher.combine(introduction)
        hasher.combine(link)
        
        // Combine each chapter into the hash
        for chapter in chapters {
            hasher.combine(chapter.title)
            hasher.combine(chapter.link)
        }
    }
}

