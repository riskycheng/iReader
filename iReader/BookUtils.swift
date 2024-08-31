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
        
        let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        
        var pages: [String] = []
        var currentRange = CFRangeMake(0, 0)
        
        while currentRange.location < attributedString.length {
            let frame = CTFramesetterCreateFrame(frameSetter, currentRange, path, nil)
            let frameRange = CTFrameGetVisibleStringRange(frame)
            
            if frameRange.length == 0 {
                break
            }
            
            let pageContent = (content as NSString).substring(with: NSRange(location: currentRange.location, length: frameRange.length))
            pages.append(pageContent)
            
            currentRange.location += frameRange.length
        }
        
        return pages
    }
}
