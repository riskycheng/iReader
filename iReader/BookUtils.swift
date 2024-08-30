import SwiftUI
import CoreText

struct BookUtils {
    static func splitContentIntoPages(content: String, size: CGSize, font: UIFont, lineSpacing: CGFloat) -> [String] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: content, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        let path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        
        var pages: [String] = []
        var currentIndex = 0
        let contentLength = content.count
        
        while currentIndex < contentLength {
            autoreleasepool {
                let frameRange = CFRangeMake(currentIndex, 0)
                let frame = CTFramesetterCreateFrame(framesetter, frameRange, path, nil)
                let visibleRange = CTFrameGetVisibleStringRange(frame)
                
                if visibleRange.length > 0 {
                    let pageEndIndex = min(currentIndex + visibleRange.length, contentLength)
                    var pageContent = (content as NSString).substring(with: NSRange(location: currentIndex, length: pageEndIndex - currentIndex))
                    
                    // Trim leading empty lines
                    pageContent = pageContent.replacingOccurrences(of: "^\n+", with: "", options: .regularExpression)
                    
                    // Trim trailing empty lines
                    pageContent = pageContent.replacingOccurrences(of: "\n+$", with: "", options: .regularExpression)
                    
                    pages.append(pageContent)
                    currentIndex = currentIndex + visibleRange.length
                } else {
                    // Fallback: add at least one character if nothing fits
                    let endIndex = min(currentIndex + 1, contentLength)
                    let singleCharContent = (content as NSString).substring(with: NSRange(location: currentIndex, length: endIndex - currentIndex))
                    pages.append(singleCharContent)
                    currentIndex = endIndex
                }
            }
        }
        
        return pages
    }
}
