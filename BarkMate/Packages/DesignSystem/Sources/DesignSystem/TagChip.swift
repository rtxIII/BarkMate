//
//  TagChip.swift
//  DesignSystem
//
//  统一的标签显示。Timeline / Memo 编辑器 / 搜索结果通用。
//

import SwiftUI

public struct TagChip: View {

    public enum Style {
        /// `#tag` — 标签
        case tag
        /// 分组徽章（accentColor 底）
        case group
    }

    private let text: String
    private let style: Style

    public init(_ text: String, style: Style = .tag) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(displayText)
            .font(.caption2)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, BarkTheme.Spacing.sm)
            .padding(.vertical, BarkTheme.Spacing.xs)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: BarkTheme.Corner.chip))
    }

    private var displayText: String {
        switch style {
        case .tag: return "#\(text)"
        case .group: return text
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .tag: return BarkTheme.Palette.chipBackground
        case .group: return BarkTheme.Palette.groupPill
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .tag: return .secondary
        case .group: return .accentColor
        }
    }
}

#Preview {
    HStack {
        TagChip("work")
        TagChip("urgent-task")
        TagChip("system", style: .group)
    }
    .padding()
}
