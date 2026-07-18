//
//  SummaryPanel.swift
//  DesignSystem
//
//  设备端 LLM 摘要面板。三态:ready(Summarize 按钮)/ loading(3 行骨架)/
//  generated(摘要文本 + 缓存标签)。Phase 6 真正接 FoundationModels。
//
//  - 旧 init(state:, onSummarize:)         → 暖纸圆角卡 + paperHot 底
//  - 新 init(state:, onSummarize:, style: .missionControl)
//                                          → 战术风:hull 底 + 1pt dashed ruleHot + lime 标签
//

import SwiftUI

public struct SummaryPanel: View {
    public enum Style {
        case missionControl
    }

    private enum Variant {
        case classic
        case missionControl
    }

    private let state: SummaryPanelState
    private let onSummarize: () -> Void
    private let variant: Variant

    public init(state: SummaryPanelState, onSummarize: @escaping () -> Void) {
        self.state = state
        self.onSummarize = onSummarize
        self.variant = .classic
    }

    public init(state: SummaryPanelState, onSummarize: @escaping () -> Void, style: Style) {
        self.state = state
        self.onSummarize = onSummarize
        switch style {
        case .missionControl: self.variant = .missionControl
        }
    }

    public var body: some View {
        switch variant {
        case .classic: classicBody
        case .missionControl: missionControlBody
        }
    }

    // MARK: - Classic

    private var classicBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            classicHeader

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
    private var classicHeader: some View {
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
                    .accessibilityIdentifier("agent-detail-summarize")
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

    // MARK: - Mission Control

    private var missionControlBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mcTagText)
                .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(MissionControl.Color.lime)

            switch state {
            case .ready:
                HStack {
                    Text("Tap summarize when ready. On-device LLM in Phase 6.")
                        .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                        .lineSpacing(4)
                        .foregroundStyle(MissionControl.Color.inkSoft)
                    Spacer(minLength: 8)
                    Button("Summarize", action: onSummarize)
                        .buttonStyle(MCSummarizeStyle())
                        .accessibilityIdentifier("agent-detail-summarize")
                }
            case .loading:
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle().fill(MissionControl.Color.ruleHot).frame(height: 6)
                    Rectangle().fill(MissionControl.Color.ruleHot).frame(width: 220, height: 6)
                    Rectangle().fill(MissionControl.Color.ruleHot).frame(width: 140, height: 6)
                }
            case .generated(let text, _):
                Text(text)
                    .font(MissionControl.Font.jetBrainsMono(size: 12, weight: .regular))
                    .lineSpacing(5)
                    .foregroundStyle(MissionControl.Color.ink)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MissionControl.Color.hull)
        .overlay(
            Rectangle()
                .strokeBorder(
                    MissionControl.Color.ruleHot,
                    style: StrokeStyle(lineWidth: MissionControl.Border.hairline, dash: [4])
                )
        )
    }

    private var mcTagText: String {
        switch state {
        case .ready:
            return "[ on-device summary · ready ]"
        case .loading:
            return "[ on-device summary · running ]"
        case .generated(_, let cacheLabel):
            if let cacheLabel { return "[ on-device summary · \(cacheLabel) ]" }
            return "[ on-device summary ]"
        }
    }
}

private struct MCSummarizeStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(configuration.isPressed ? MissionControl.Color.void : MissionControl.Color.lime)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? MissionControl.Color.lime : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(MissionControl.Color.lime, lineWidth: MissionControl.Border.hairline)
            )
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

#Preview("Mission Control") {
    VStack(spacing: 16) {
        SummaryPanel(state: .ready, onSummarize: {}, style: .missionControl)
        SummaryPanel(state: .loading, onSummarize: {}, style: .missionControl)
        SummaryPanel(state: .generated(
            text: "任务已完成 04 / 07 步,正在等待用户确认是否覆盖现有 mock。",
            cacheLabel: "cached · 5m"
        ), onSummarize: {}, style: .missionControl)
    }
    .padding(16)
    .mcScreenBackground()
}
