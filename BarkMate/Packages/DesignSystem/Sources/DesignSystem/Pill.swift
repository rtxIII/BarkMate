//
//  Pill.swift
//  DesignSystem
//
//  小号大写胶囊标签。dark 模式用于深色 hero 卡内部。
//

import SwiftUI

public struct Pill: View {
    private let text: String
    private let dark: Bool

    public init(_ text: String, dark: Bool = false) {
        self.text = text
        self.dark = dark
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.7)
            .foregroundStyle(dark ? .white.opacity(0.72) : BarkTheme.Palette.ink.opacity(0.58))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                dark ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(BarkTheme.Palette.ink.opacity(0.08)),
                in: Capsule()
            )
    }
}

#Preview {
    HStack(spacing: 8) {
        Pill("agent")
        Pill("first push", dark: true)
        Pill("status: waiting")
    }
    .padding()
    .background(BarkTheme.Palette.paperHot)
}
