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

    public init(count: Int, bucket: MissionControl.Status.Bucket) {
        self.count = count
        self.bucket = bucket
    }

    public var body: some View {
        let isAlert = bucket == .needsYou
        let accent = MissionControl.Status.bucketColor(bucket)

        return VStack(alignment: .leading, spacing: 6) {
            Text(formattedCount)
                .font(MissionControl.Font.interTight(size: 44, weight: .black))
                .tracking(-2.2)
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(MissionControl.Status.bucketTitle(bucket).uppercased())
                .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(MissionControl.Color.inkSoft)

            Text(MissionControl.Status.bucketSubtitle(bucket))
                .font(MissionControl.Font.jetBrainsMono(size: 9.5, weight: .regular))
                .foregroundStyle(MissionControl.Color.inkSoft)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MissionControl.Color.void)
        .overlay(
            Rectangle()
                .stroke(
                    isAlert ? MissionControl.Color.amber : MissionControl.Color.rule,
                    lineWidth: MissionControl.Border.hairline
                )
        )
        .overlay {
            if isAlert {
                Rectangle()
                    .stroke(MissionControl.Color.amberGlow, lineWidth: 1)
                    .padding(MissionControl.Border.hairline)
            }
        }
    }

    private var formattedCount: String {
        count < 10 ? "0\(count)" : "\(count)"
    }
}

#Preview {
    HStack(spacing: 8) {
        MCTriageCell(count: 2, bucket: .needsYou)
        MCTriageCell(count: 3, bucket: .running)
        MCTriageCell(count: 1, bucket: .settled)
    }
    .padding(16)
    .mcScreenBackground()
}
