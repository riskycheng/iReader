import UIKit
import CoreText

struct BookUtils {
    static func splitContentIntoPages(content: String, pageSize: CGSize, font: UIFont, lineSpacing: CGFloat) -> ([String], String) {
        var pages: [String] = []
        var currentOffset = 0
        var logMessages = ""

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        let lineHeight = calculateLineHeight(font: font, lineSpacing: lineSpacing)
        let expectedLineCount = Int(pageSize.height / lineHeight)

        logMessages += "Calculated Line Height: \(lineHeight)\n"
        logMessages += "Visible Region Height: \(pageSize.height)\n"
        logMessages += "Expected Line Count: \(expectedLineCount)\n"

        let attributedText = NSAttributedString(string: content, attributes: attributes)
        let fullText = attributedText.string
        let lines = fullText.components(separatedBy: .newlines) // Separate the content by lines
        
        var pageContent = ""
        var pageHeight: CGFloat = 0
        var lineIndex = 0
        
        while lineIndex < lines.count {
            let line = lines[lineIndex].trimmingCharacters(in: .whitespaces) // Trim spaces in each line
            
            if line.isEmpty {
                lineIndex += 1
                continue
            }

            let attributedLine = NSAttributedString(string: line, attributes: attributes)
            let lineHeight = attributedLine.boundingRect(with: CGSize(width: pageSize.width, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size.height
            
            if pageHeight + lineHeight > pageSize.height {
                // Add the page content to the pages array and reset for the next page
                pages.append(pageContent.trimmingCharacters(in: .whitespacesAndNewlines))
                logMessages += "Page \(pages.count)\n"
                logMessages += "Text Region Height: \(pageHeight)\n"
                logMessages += "Character Count: \(pageContent.count)\n"
                logMessages += "-----------------------------\n"
                
                pageContent = ""
                pageHeight = 0
            } else {
                pageContent += line + "\n"
                pageHeight += lineHeight
                lineIndex += 1
            }
        }
        
        // Add the last page content if any
        if !pageContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pages.append(pageContent.trimmingCharacters(in: .whitespacesAndNewlines))
            logMessages += "Page \(pages.count)\n"
            logMessages += "Text Region Height: \(pageHeight)\n"
            logMessages += "Character Count: \(pageContent.count)\n"
            logMessages += "-----------------------------\n"
        }

        return (pages, logMessages)
    }
    
    static private func calculateLineHeight(font: UIFont, lineSpacing: CGFloat) -> CGFloat {
        let text = "A"
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return size.height + lineSpacing
    }
}
