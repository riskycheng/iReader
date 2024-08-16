import Foundation
import SwiftSoup

struct HTMLBookParser {
    static func parseHTML(_ html: String, baseURL: String) -> Book? {
        do {
            let document = try SwiftSoup.parse(html)
            
            // Parse title
            let title = try document.title()
            
            // Parse author
            let authorElement = try document.select(".info .small span").first()
            let author = try authorElement?.text() ?? "Unknown Author"
            
            // Parse cover image URL
            let coverElement = try document.select(".info .cover img").first()
            let coverURL = try coverElement?.attr("src") ?? ""
            
            // Parse last updated date
            let lastUpdatedElement = try document.select(".info .small span.last").first()
            let lastUpdated = try lastUpdatedElement?.text() ?? "Unknown Date"
            
            // Parse status
            let statusElement = try document.select(".info .small span").get(1)
            let status = try statusElement.text()
            
            // Parse introduction
            let introElement = try document.select(".intro dl dd").first()
            let introduction = try introElement?.text() ?? "No Introduction Available"
            
            // Parse chapter list and append baseURL to chapter links
            let chapterElements = try document.select(".listmain dd a")
            var chapters: [(title: String, link: String)] = []
            for chapterElement in chapterElements {
                let chapterTitle = try chapterElement.text()
                let chapterLink = try chapterElement.attr("href")
                
                // Combine baseURL and chapterLink to create the complete link
                let completeChapterLink = baseURL + chapterLink
                chapters.append((title: chapterTitle, link: completeChapterLink))
            }
            
            // Create and return the Book object
            return Book(
                title: title,
                author: author,
                coverURL: coverURL,
                lastUpdated: lastUpdated,
                status: status,
                introduction: introduction,
                chapters: chapters,
                link: baseURL // Save the base URL to use later
            )
        } catch {
            print("Error parsing HTML: \(error)")
            return nil
        }
    }
}
