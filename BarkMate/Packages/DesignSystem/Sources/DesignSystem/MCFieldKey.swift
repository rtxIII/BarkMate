//
//  MCFieldKey.swift
//  DesignSystem
//
//  Setup 屏字段说明卡(key → value 二列表)。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .field-key       L858  padding 14,1pt rule,hull 底
//    .field-key .row  L864  grid 110pt + 1fr,gap 12,padding 6/0
//    .field-key .row  L869  底部 1pt dashed rule
//    .field-key .k    L873  cyan 700
//    .field-key .v    L877  inkSoft line-height 1.45
//

import SwiftUI

public struct MCFieldKey: View {
    public struct Entry: Identifiable {
        public let id = UUID()
        public let key: String
        public let value: String

        public init(key: String, value: String) {
            self.key = key
            self.value = value
        }
    }

    private let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                row(for: entry, isLast: index == entries.count - 1)
            }
        }
        .padding(14)
        .background(MissionControl.Color.hull)
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.rule, lineWidth: MissionControl.Border.hairline)
        )
    }

    private func row(for entry: Entry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.key)
                .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .bold))
                .foregroundStyle(MissionControl.Color.cyan)
                .frame(width: 110, alignment: .leading)
            Text(entry.value)
                .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(MissionControl.Color.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .strokeBorder(
                        MissionControl.Color.rule,
                        style: StrokeStyle(lineWidth: MissionControl.Border.hairline, dash: [3])
                    )
                    .frame(height: MissionControl.Border.hairline)
            }
        }
    }
}

#Preview {
    MCFieldKey(entries: [
        .init(key: "group", value: "agent_id"),
        .init(key: "task_id", value: "同一任务的聚合键"),
        .init(key: "agent_status", value: "running / waiting_input / blocked / done / failed"),
        .init(key: "progress", value: "3/7 或 45%")
    ])
    .padding(.horizontal, 16)
    .mcScreenBackground()
}
