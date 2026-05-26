//
//  MockCardModifier.swift
//  DesignSystem
//
//  Mock 契约的 paperHot 卡通用样式:14pt 内边距 + 圆角 22 + 1pt 描边 + 浅阴影。
//

import SwiftUI

public extension View {
    /// 应用 paperHot 卡通用样式,等价 mock prototype 里的 `.mockCardPadding()`。
    func mockCardPadding() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                BarkTheme.Palette.paperHot.opacity(0.76),
                in: RoundedRectangle(cornerRadius: BarkTheme.Corner.mockCard, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BarkTheme.Corner.mockCard, style: .continuous)
                    .stroke(BarkTheme.Palette.ink.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: BarkTheme.Palette.ink.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    /// SummaryPanel 用的次级文本样式(13pt medium + 3pt 行距 + ink 76%)。
    func summaryTextStyle() -> some View {
        self
            .font(.system(size: 13, weight: .medium))
            .lineSpacing(3)
            .foregroundStyle(BarkTheme.Palette.ink.opacity(0.76))
    }
}
