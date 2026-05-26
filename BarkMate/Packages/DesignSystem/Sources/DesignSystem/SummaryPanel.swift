//
//  SummaryPanel.swift
//  DesignSystem
//
//  设备端 LLM 摘要面板。三态:ready(Summarize 按钮)/ loading(3 行骨架)/
//  generated(摘要文本 + 缓存标签)。Phase 6 真正接 FoundationModels。
//

import SwiftUI

public struct SummaryPanel: View {
    private let state: SummaryPanelState
    private let onSummarize: () -> Void

    public init(state: SummaryPanelState, onSummarize: @escaping () -> Void) {
        self.state = state
        self.onSummarize = onSummarize
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            switch state {
            case .ready:
                Text("点击按钮后模拟本地摘要。真实版本会在支持设备上调用 Apple Intelligence,不支持时仍显示原始 step。")
                    .summaryTextStyle()
            case .loading:
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonLine(widthFraction: 1.0)
                    SkeletonLine(widthFraction: 0.72)
                    SkeletonLine(widthFraction: 0.48)
                }
            case .generated(let text, _):
                Text(text).summaryTextStyle()
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: BarkTheme.Corner.largeCard, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BarkTheme.Palette.paperHot.opacity(0.94),
                            BarkTheme.Palette.paperDeep.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: BarkTheme.Corner.largeCard, style: .continuous)
                .stroke(BarkTheme.Palette.ink.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: BarkTheme.Palette.ink.opacity(0.06), radius: 14, x: 0, y: 7)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("On-device progress summary")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(BarkTheme.Palette.ink.opacity(0.54))
            Spacer()
            switch state {
            case .ready:
                Button("Summarize", action: onSummarize)
                    .buttonStyle(PrimaryCapsuleButtonStyle(compact: true))
            case .loading:
                EmptyView()
            case .generated(_, let cacheLabel):
                if let cacheLabel {
                    Text(cacheLabel)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(BarkTheme.Palette.ink.opacity(0.50))
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SummaryPanel(state: .ready) {}
        SummaryPanel(state: .loading) {}
        SummaryPanel(state: .generated(
            text: "正在重构 auth middleware,已经处理 3/8 个文件。当前没有阻塞,下一步是修复测试中的类型错误。",
            cacheLabel: "cached · 5m"
        )) {}
    }
    .padding()
    .background(MockScreenBackground())
}
