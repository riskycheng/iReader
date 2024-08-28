import UIKit
import CoreText

struct BookUtils {
    static func splitContentIntoPages(content: String, pageSize: CGSize, font: UIFont, lineSpacing: CGFloat, logMessages: inout String) -> [String] {
        var pages: [String] = []
        var currentOffset = 0
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedText = NSAttributedString(string: content, attributes: attributes)
        
        while currentOffset < attributedText.length {
            let remainingLength = attributedText.length - currentOffset
            let textToDraw = attributedText.attributedSubstring(from: NSRange(location: currentOffset, length: remainingLength))
            
            // Measure the height of the text block
            let textSize = textToDraw.boundingRect(with: CGSize(width: pageSize.width, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size
            
            logMessages += "Measuring text block:\n"
            logMessages += "Text block height: \(textSize.height)\n"
            logMessages += "Page size height: \(pageSize.height)\n"
            
            // Calculate the visible range
            let visibleRange = calculateVisibleRange(textToDraw: textToDraw, pageSize: pageSize)
            logMessages += "Visible range length: \(visibleRange.length)\n"
            
            if visibleRange.length == 0 {
                break
            }
            
            let pageContent = textToDraw.attributedSubstring(from: NSRange(location: 0, length: visibleRange.length)).string
            pages.append(pageContent)
            currentOffset += visibleRange.length
            
            logMessages += "Added page content:\n"
            logMessages += pageContent + "\n"
        }
        
        return pages
    }
    
    static private func calculateVisibleRange(textToDraw: NSAttributedString, pageSize: CGSize) -> NSRange {
        let framesetter = CTFramesetterCreateWithAttributedString(textToDraw)
        let path = CGPath(rect: CGRect(origin: .zero, size: pageSize), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        let visibleRange = CTFrameGetVisibleStringRange(frame)
        return NSRange(location: visibleRange.location, length: visibleRange.length)
    }
}
