import Foundation

struct Book {
    var title: String
    var author: String
    var coverURL: String
    var lastUpdated: String
    var status: String
    var introduction: String
    var chapters: [(title: String, link: String)]
    var link: String // Add this property
}
