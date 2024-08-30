import SwiftUI

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
        var currentRange = CFRangeMake(0, 0)
        var hasMorePages = true
        
        while hasMorePages {
            let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
            let range = CTFrameGetVisibleStringRange(frame)
            
            if range.length > 0 {
                let pageContent = (content as NSString).substring(with: NSRange(location: range.location, length: range.length))
                pages.append(pageContent)
                
                currentRange = CFRangeMake(range.location + range.length, 0)
            } else {
                hasMorePages = false
            }
        }
        
        return pages
    }
}
