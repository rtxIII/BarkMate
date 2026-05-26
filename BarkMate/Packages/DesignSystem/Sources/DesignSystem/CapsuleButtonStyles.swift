//
//  CapsuleButtonStyles.swift
//  DesignSystem
//
//  Mock 契约的三种胶囊按钮:Primary(ink 填充)/ Secondary(paperHot)/ Chip(选中 vs 未选)。
//

import SwiftUI

public struct PrimaryCapsuleButtonStyle: ButtonStyle {
    public var compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 11 : 12, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 10 : 13)
            .padding(.vertical, compact ? 7 : 10)
            .background(BarkTheme.Palette.ink, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

public struct SecondaryCapsuleButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(BarkTheme.Palette.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(BarkTheme.Palette.paperHot.opacity(0.72), in: Capsule())
            .overlay(Capsule().stroke(BarkTheme.Palette.ink.opacity(0.12), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

public struct ChipButtonStyle: ButtonStyle {
    public let isSelected: Bool

    public init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(isSelected ? .white : BarkTheme.Palette.ink.opacity(0.68))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                isSelected ? BarkTheme.Palette.ink : BarkTheme.Palette.paperHot.opacity(0.72),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(BarkTheme.Palette.ink.opacity(isSelected ? 0 : 0.12), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

#Preview {
    VStack(spacing: 12) {
        Button("Demo push") {}.buttonStyle(PrimaryCapsuleButtonStyle())
        Button("Reconcile stale") {}.buttonStyle(SecondaryCapsuleButtonStyle())
        HStack {
            Button("All") {}.buttonStyle(ChipButtonStyle(isSelected: true))
            Button("Running") {}.buttonStyle(ChipButtonStyle(isSelected: false))
        }
    }
    .padding()
    .background(BarkTheme.Palette.paperHot)
}
