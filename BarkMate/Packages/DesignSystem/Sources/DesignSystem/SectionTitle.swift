//
//  SectionTitle.swift
//  DesignSystem
//
//  Dashboard / History 等 section 顶部的大写小标题 + 右侧计数文案。
//

import SwiftUI

public struct SectionTitle: View {
    private let title: String
    private let trailing: String

    public init(_ title: String, trailing: String) {
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(BarkTheme.Palette.ink)
            Spacer()
            Text(trailing)
                .font(.caption.weight(.bold))
                .foregroundStyle(BarkTheme.Palette.ink.opacity(0.50))
        }
        .padding(.top, 2)
    }
}

#Preview {
    SectionTitle("Active Agents", trailing: "6 cards")
        .padding()
        .background(BarkTheme.Palette.paperHot)
}
