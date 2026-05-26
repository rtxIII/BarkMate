//
//  SettingRows.swift
//  DesignSystem
//
//  Settings tab 用的 paperHot 卡片行:SettingRow(右侧 Pill badge)+
//  SettingToggleRow(右侧 Toggle)。
//

import SwiftUI

public struct SettingRow: View {
    private let title: String
    private let detail: String
    private let badge: String?

    public init(title: String, detail: String, badge: String? = nil) {
        self.title = title
        self.detail = detail
        self.badge = badge
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.heavy))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(BarkTheme.Palette.ink.opacity(0.58))
            }
            Spacer()
            if let badge {
                Pill(badge)
            }
        }
        .mockCardPadding()
    }
}

public struct SettingToggleRow: View {
    private let title: String
    private let detail: String
    @Binding private var isOn: Bool

    public init(title: String, detail: String, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        self._isOn = isOn
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.heavy))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(BarkTheme.Palette.ink.opacity(0.58))
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(BarkTheme.Palette.ink)
        }
        .mockCardPadding()
    }
}

#Preview {
    @Previewable @State var toggle: Bool = true
    return VStack(spacing: 10) {
        SettingRow(title: "api.day.app", detail: "Default server · key synced", badge: "online")
        SettingToggleRow(
            title: "On-device summary",
            detail: "Use Apple Intelligence when available.",
            isOn: $toggle
        )
    }
    .padding()
    .background(MockScreenBackground())
}
