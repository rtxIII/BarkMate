//
//  SkeletonLine.swift
//  DesignSystem
//
//  SummaryPanel.loading 态用的渐变骨架行。
//

import SwiftUI

public struct SkeletonLine: View {
    private let widthFraction: CGFloat

    public init(widthFraction: CGFloat) {
        self.widthFraction = widthFraction
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 999)
            .fill(
                LinearGradient(
                    colors: [
                        BarkTheme.Palette.ink.opacity(0.07),
                        BarkTheme.Palette.ink.opacity(0.16),
                        BarkTheme.Palette.ink.opacity(0.07)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 11)
            .scaleEffect(x: widthFraction, y: 1, anchor: .leading)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        SkeletonLine(widthFraction: 1.0)
        SkeletonLine(widthFraction: 0.72)
        SkeletonLine(widthFraction: 0.48)
    }
    .padding()
    .background(BarkTheme.Palette.paperHot)
}
