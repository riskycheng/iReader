import UIKit
import CoreText

struct BookUtils {
    static func splitContentIntoPages(content: String, pageSize: CGSize, font: UIFont, lineSpacing: CGFloat) -> ([String], String) {
        var pages: [String] = []
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
            let line = lines[lineIndex].trimmingCharacters(in: .whitespacesAndNewlines) // Trim spaces and newlines in each line
            
            if line.isEmpty {
                lineIndex += 1
                continue
            }

            let attributedLine = NSAttributedString(string: line, attributes: attributes)
            let lineHeight = attributedLine.boundingRect(with: CGSize(width: pageSize.width, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size.height
            
            if pageHeight + lineHeight > pageSize.height {
                // Trim trailing empty lines from the page content before adding to pages array
                pageContent = pageContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if !pageContent.isEmpty {
                    pages.append(pageContent)
                    logMessages += "Page \(pages.count)\n"
                    logMessages += "Text Region Height: \(pageHeight)\n"
                    logMessages += "Character Count: \(pageContent.count)\n"
                    logMessages += "Content:\n\(pageContent)\n"
                    logMessages += "-----------------------------\n"
                }
                
                pageContent = ""
                pageHeight = 0
            } else {
                // Only add non-empty lines to the page content
                pageContent += line + "\n"
                logMessages += "Line \(lineIndex + 1): '\(line)' (Height: \(lineHeight))\n" // Log each line with height
                pageHeight += lineHeight
                lineIndex += 1
            }
        }
        
        // Final page processing: trim and add any remaining content
        pageContent = pageContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pageContent.isEmpty {
            pages.append(pageContent)
            logMessages += "Page \(pages.count)\n"
            logMessages += "Text Region Height: \(pageHeight)\n"
            logMessages += "Character Count: \(pageContent.count)\n"
            logMessages += "Content:\n\(pageContent)\n"
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
