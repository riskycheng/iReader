import UIKit

struct BookUtils {
    static func splitContentIntoPages(content: String, size: CGSize, font: UIFont, lineSpacing: CGFloat) -> [String] {
        let attributedString = NSAttributedString(
            string: content,
            attributes: [
                .font: font,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = lineSpacing
                    return style
                }()
            ]
        )
        
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        
        var pages: [String] = []
        var currentIndex = 0
        
        while currentIndex < attributedString.length {
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(currentIndex, 0), path, nil)
            let range = CTFrameGetVisibleStringRange(frame)
            
            if range.length == 0 {
                break
            }
            
            let pageContent = (attributedString.string as NSString).substring(with: NSRange(location: range.location, length: range.length))
            pages.append(pageContent)
            
            currentIndex += range.length
        }
        
        return pages
    }
}
