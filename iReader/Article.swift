struct Article {
    var title: String
    var totalContent: String
    var splitPages: [String]
    var pagesCount: Int
    var prevLink: String?
    var nextLink: String?
    
    init(title: String, totalContent: String, splitPages: [String], prevLink: String?, nextLink: String?) {
        self.title = title
        self.totalContent = totalContent
        self.splitPages = splitPages
        self.pagesCount = splitPages.count
        self.prevLink = prevLink
        self.nextLink = nextLink
    }
}
