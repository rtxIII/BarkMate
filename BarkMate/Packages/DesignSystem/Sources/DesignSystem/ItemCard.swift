//
//  ItemCard.swift
//  DesignSystem
//
//  Timeline 卡片，自动按 item.type 切换 push/memo 视觉。
//

import SwiftUI
import Models

public struct ItemCard: View {

    private let item: Item

    public init(item: Item) {
        self.item = item
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BarkTheme.Spacing.sm) {
            headerRow

            if let title = item.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
            }

            if let subtitle = item.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !item.body.isEmpty {
                MarkdownBodyView(
                    body: item.body,
                    bodyType: item.bodyType,
                    lineLimit: item.type == .push ? 3 : 6
                )
                .font(.body)
                .foregroundStyle(.primary)
            }

            footerRow
        }
        .padding(BarkTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            BarkTheme.Palette.cardBackground,
            in: RoundedRectangle(cornerRadius: BarkTheme.Corner.card)
        )
        .overlay(alignment: .topTrailing) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.tint)
                    .font(.caption2)
                    .padding(BarkTheme.Spacing.sm)
            }
        }
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: BarkTheme.Spacing.xs) {
            Image(systemName: item.type == .push ? "bell.badge" : "note.text")
                .font(.caption2)
                .foregroundStyle(.tint)
            Text(item.type == .push ? "Push" : "Memo")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(item.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var footerRow: some View {
        let tags = Array(item.tags.prefix(4))
        if !tags.isEmpty || (item.group?.isEmpty == false) {
            HStack(spacing: BarkTheme.Spacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    TagChip(tag)
                }
                if let group = item.group, !group.isEmpty {
                    TagChip(group, style: .group)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
