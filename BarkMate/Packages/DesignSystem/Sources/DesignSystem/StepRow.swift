//
//  StepRow.swift
//  DesignSystem
//
//  AgentDetailView 中单条 step 历史的展示。
//  左侧 monospace 时间列(42pt)+ 右侧 status badge + heavy 14pt title + 12pt medium body。
//

import SwiftUI

public struct StepRow: View {
    private let data: StepRowData

    public init(data: StepRowData) {
        self.data = data
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(data.timeLabel)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(BarkTheme.Palette.ink.opacity(0.48))
                .frame(width: 42, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                StatusBadge(status: data.status, compact: true)
                Text(data.title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(BarkTheme.Palette.ink)
                Text(data.body)
                    .font(.system(size: 12, weight: .medium))
                    .lineSpacing(2)
                    .foregroundStyle(BarkTheme.Palette.ink.opacity(0.58))
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            BarkTheme.Palette.paperHot.opacity(0.78),
            in: RoundedRectangle(cornerRadius: BarkTheme.Corner.mockCard, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BarkTheme.Corner.mockCard, style: .continuous)
                .stroke(BarkTheme.Palette.ink.opacity(0.10), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 10) {
        StepRow(data: StepRowData(
            id: UUID(),
            timeLabel: "10:29",
            status: .running,
            title: "Fixing unit tests",
            body: "Typecheck found two mock signatures that need to be updated."
        ))
        StepRow(data: StepRowData(
            id: UUID(),
            timeLabel: "10:25",
            status: .running,
            title: "Updated auth.ts",
            body: "Extracted token validation into a smaller middleware function."
        ))
    }
    .padding()
    .background(MockScreenBackground())
}
