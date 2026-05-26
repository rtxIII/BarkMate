//
//  MockScreenBackground.swift
//  DesignSystem
//
//  暖色渐变 + 两团模糊光晕。Mock 契约见 AgentMockPrototypeView.MockScreenBackground。
//

import SwiftUI

public struct MockScreenBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BarkTheme.Palette.paperHot,
                    BarkTheme.Palette.paperWarm,
                    BarkTheme.Palette.paperCool
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(BarkTheme.Palette.warningYellow.opacity(0.20))
                .frame(width: 240, height: 240)
                .blur(radius: 28)
                .offset(x: -170, y: -360)
            Circle()
                .fill(BarkTheme.Palette.infoCyan.opacity(0.15))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: 160, y: -330)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    MockScreenBackground()
}
