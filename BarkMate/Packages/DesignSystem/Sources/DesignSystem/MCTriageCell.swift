//
//  MCTriageCell.swift
//  DesignSystem
//
//  Heads-up 顶部 triage 三栏 cell。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .tri-cell           L553  padding 10/10,1pt rule,void 底
//    .tri-cell .num      L559  Inter Tight 44pt Black,-0.05em,line-height 0.88
//    .tri-cell .lbl      L566  9pt uppercase tracking 0.14em,inkSoft
//    .tri-cell .sub      L575  9.5pt inkSoft
//    .alert              L581  amber 数字 + amber 边 + inset amber glow
//    .run                L583  cyan 数字
//    .idle               L584  inkMute 数字
//

import SwiftUI

public struct MCTriageCell: View {
    private let count: Int
    private let bucket: MissionControl.Status.Bucket
    private let subtitle: String
    private let isSelected: Bool
    private let onTap: (() -> Void)?

    /// - Parameters:
    ///   - subtitle: 数字下方的小字。mock B 用于动态计数文案
    ///     (如 "02 CI · 01 agent" / "01 done · 01 fail"),由 caller 根据实际数据生成。
    ///   - isSelected: 作为页面过滤器时的选中态(bucket 色实心反白)。默认 false。
    ///   - onTap: 提供后 cell 变为可点按的过滤入口;nil 时退化为纯展示。
    public init(
        count: Int,
        bucket: MissionControl.Status.Bucket,
        subtitle: String,
        isSelected: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.count = count
        self.bucket = bucket
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        let content = cellContent
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
                .accessibilityIdentifier("triage-cell-\(bucket.rawValue)")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        } else {
            content
        }
    }

    private var cellContent: some View {
        let isAlert = bucket == .needsYou
        let accent = MissionControl.Status.bucketColor(bucket)
        // 选中(过滤激活)→ bucket 色实心 + void 深字反白;数字/标题/小字都压深色。
        let numberColor = isSelected ? MissionControl.Color.void : accent
        let labelColor = isSelected ? MissionControl.Color.void : MissionControl.Color.inkSoft

        return VStack(alignment: .leading, spacing: 6) {
            Text(formattedCount)
                .font(MissionControl.Font.interTight(size: 44, weight: .black))
                .tracking(-2.2)
                .foregroundStyle(numberColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(MissionControl.Status.bucketTitle(bucket).uppercased())
                .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(labelColor)

            Text(subtitle)
                .font(MissionControl.Font.jetBrainsMono(size: 9.5, weight: .regular))
                .foregroundStyle(labelColor)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? accent : MissionControl.Color.void)
        .overlay(
            Rectangle()
                .stroke(
                    isSelected ? accent : (isAlert ? MissionControl.Color.amber : MissionControl.Color.rule),
                    lineWidth: MissionControl.Border.hairline
                )
        )
        .overlay {
            if isAlert && !isSelected {
                Rectangle()
                    .stroke(MissionControl.Color.amberGlow, lineWidth: 1)
                    .padding(MissionControl.Border.hairline)
            }
        }
        .contentShape(Rectangle())
    }

    private var formattedCount: String {
        count < 10 ? "0\(count)" : "\(count)"
    }
}

#Preview {
    HStack(spacing: 8) {
        MCTriageCell(count: 2, bucket: .needsYou, subtitle: "wait input · stuck on token")
        MCTriageCell(count: 3, bucket: .running, subtitle: "02 CI · 01 agent")
        MCTriageCell(count: 2, bucket: .settled, subtitle: "01 done · 01 fail")
    }
    .padding(16)
    .mcScreenBackground()
}
