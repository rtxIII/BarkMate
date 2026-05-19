//
//  HighlightedText.swift
//  DesignSystem
//
//  搜索结果高亮：把匹配子串加粗 + 着色。大小写不敏感。
//

import SwiftUI

public struct HighlightedText: View {

    private let text: String
    private let highlight: String
    private let lineLimit: Int?

    public init(_ text: String, highlight: String, lineLimit: Int? = nil) {
        self.text = text
        self.highlight = highlight
        self.lineLimit = lineLimit
    }

    public var body: some View {
        Text(attributed)
            .lineLimit(lineLimit)
    }

    private var attributed: AttributedString {
        var attr = AttributedString(text)
        let trimmed = highlight.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return attr }

        let lower = text.lowercased() as NSString
        let target = trimmed.lowercased() as NSString
        var searchRange = NSRange(location: 0, length: lower.length)

        while searchRange.location < lower.length {
            let foundRange = lower.range(
                of: target as String,
                options: .literal,
                range: searchRange
            )
            if foundRange.location == NSNotFound { break }
            if let stringRange = Range(foundRange, in: text),
               let attrRange = attr.range(of: String(text[stringRange])) {
                attr[attrRange].font = .body.bold()
                attr[attrRange].foregroundColor = .accentColor
            }
            let nextLocation = foundRange.location + foundRange.length
            searchRange = NSRange(location: nextLocation, length: lower.length - nextLocation)
        }
        return attr
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        HighlightedText("Deploy v1.2.3 to production", highlight: "deploy")
        HighlightedText("CPU 高 #urgent", highlight: "高")
    }
    .padding()
}
