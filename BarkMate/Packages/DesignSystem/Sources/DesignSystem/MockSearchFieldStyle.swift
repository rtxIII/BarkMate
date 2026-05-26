//
//  MockSearchFieldStyle.swift
//  DesignSystem
//
//  Search tab 顶部 TextField 的 paperHot 圆角样式。
//

import SwiftUI

public struct MockSearchFieldStyle: TextFieldStyle {
    public init() {}

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.body.weight(.bold))
            .padding(14)
            .background(
                BarkTheme.Palette.paperHot.opacity(0.80),
                in: RoundedRectangle(cornerRadius: 21, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(BarkTheme.Palette.ink.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: BarkTheme.Palette.ink.opacity(0.07), radius: 14, x: 0, y: 7)
    }
}
