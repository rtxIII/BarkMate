//
//  HistoryRow.swift
//  DesignSystem
//
//  History tab 全量行 + Dashboard 底部 mini 行。两个尺寸共用 HistoryItemData。
//

import SwiftUI

public struct HistoryRow: View {
    private let data: HistoryItemData

    public init(data: HistoryItemData) {
        self.data = data
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(data.title)
                    .font(.headline.weight(.heavy))
                Text(data.body)
                    .font(.subheadline)
                    .foregroundStyle(BarkTheme.Palette.ink.opacity(0.58))
            }
            Spacer()
            Pill(data.kindBadge)
        }
        .mockCardPadding()
    }
}

public struct HistoryMiniRow: View {
    private let data: HistoryItemData

    public init(data: HistoryItemData) {
        self.data = data
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(data.title)
                    .font(.system(size: 13, weight: .heavy))
                Text(data.body)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(BarkTheme.Palette.ink.opacity(0.58))
                    .lineLimit(2)
            }
            Spacer()
            Pill(data.kindBadge)
        }
        .mockCardPadding()
    }
}

#Preview {
    VStack(spacing: 10) {
        HistoryRow(data: HistoryItemData(
            id: UUID(),
            kind: .incoming,
            kindBadge: "incoming",
            title: "Build finished",
            body: "旧 Bark 推送:main branch build completed in 12m32s.",
            updatedAt: .now
        ))
        HistoryMiniRow(data: HistoryItemData(
            id: UUID(),
            kind: .memo,
            kindBadge: "memo",
            title: "Deploy preview link",
            body: "Saved from Share Extension placeholder.",
            updatedAt: .now
        ))
    }
    .padding()
    .background(MockScreenBackground())
}
