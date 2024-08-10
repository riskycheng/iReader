import SwiftUI

struct TextStyle {
    var font: UIFont
    var lineSpacing: CGFloat
    var alignment: NSTextAlignment

    var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.alignment = alignment
        return style
    }

    // Default initializer with configurable options
    init(font: UIFont = .systemFont(ofSize: 17),
         lineSpacing: CGFloat = 1.5,
         alignment: NSTextAlignment = .natural) {
        self.font = font
        self.lineSpacing = lineSpacing
        self.alignment = alignment
    }

    // Setters for updating properties
    mutating func setFont(_ font: UIFont) {
        self.font = font
    }

    mutating func setLineSpacing(_ lineSpacing: CGFloat) {
        self.lineSpacing = lineSpacing
    }

    mutating func setAlignment(_ alignment: NSTextAlignment) {
        self.alignment = alignment
    }

    // Static properties for common styles
    static let defaultStyle = TextStyle()
    static let titleStyle = TextStyle(font: .boldSystemFont(ofSize: 24), lineSpacing: 2.0, alignment: .center)
    static let bodyStyle = TextStyle(font: .systemFont(ofSize: 17), lineSpacing: 1.5, alignment: .justified)
}
