import SwiftUI

struct BookUtils {
    static func splitContentIntoPages(content: String, size: CGSize, font: UIFont, lineSpacing: CGFloat) -> [String] {
        print("Starting page splitting. Content length: \(content.count), Page size: \(size)")
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: content, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Reduce the height slightly to create a bottom margin
        let adjustedSize = CGSize(width: size.width, height: max(size.height - 20, 100))
        let path = CGPath(rect: CGRect(origin: .zero, size: adjustedSize), transform: nil)
        
        var pages: [String] = []
        var currentIndex = 0
        let contentLength = content.count
        
        while currentIndex < contentLength {
            autoreleasepool {
                let remainingRange = CFRangeMake(currentIndex, 0)
                let frame = CTFramesetterCreateFrame(framesetter, remainingRange, path, nil)
                let frameRange = CTFrameGetVisibleStringRange(frame)
                
                print("Frame range: location \(frameRange.location), length \(frameRange.length)")
                
                if frameRange.length == 0 {
                    print("Warning: Unable to fit any text. Forcing at least one character.")
                    let endIndex = min(currentIndex + 1, contentLength)
                    let pageContent = content[content.index(content.startIndex, offsetBy: currentIndex)..<content.index(content.startIndex, offsetBy: endIndex)]
                    pages.append(String(pageContent))
                    currentIndex = endIndex
                } else {
                    let endIndex = min(currentIndex + frameRange.length, contentLength)
                    let pageContent = content[content.index(content.startIndex, offsetBy: currentIndex)..<content.index(content.startIndex, offsetBy: endIndex)]
                    pages.append(String(pageContent))
                    currentIndex = endIndex
                }
                
                print("Added page. Current index: \(currentIndex), Total pages: \(pages.count)")
            }
        }
        
        if pages.isEmpty {
            print("Error: No pages created. Adding entire content as fallback.")
            pages.append(content)
        }
        
        print("Finished splitting. Total pages: \(pages.count)")
        return pages
    }
}
