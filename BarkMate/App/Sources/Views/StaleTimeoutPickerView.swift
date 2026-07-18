//
//  StaleTimeoutPickerView.swift
//  BarkAgent
//
//  Stale timeout 阈值选择屏。单栏档位,点击 = 选中 + 持久化。
//

import SwiftUI
import Factory
import Models
import Store
import DesignSystem

struct StaleTimeoutPickerView: View {

    @Injected(\.staleTimeoutStore) private var store: StaleTimeoutStore

    @State private var selected: StaleThreshold = StaleThresholdCatalog.defaultThreshold

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                MCConsoleHeader(
                    crumbs: ["SYS", "SETTINGS", "STALE"],
                    title: "Stale timeout"
                )
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 0) {
                    MCSectionHeader("Threshold", trailing: "running → stale")
                    ForEach(StaleThresholdCatalog.options, id: \.self) { option in
                        optionRow(option)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .mcScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("stale-timeout-picker")
        .onAppear { selected = store.threshold() }
    }

    private func optionRow(_ option: StaleThreshold) -> some View {
        Button {
            store.setThreshold(option)
            selected = option
        } label: {
            MCSettingRow(title: option.displayLabel) {
                MCSettingValue(selected == option ? "✓" : "", tone: .accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stale-option-\(identifier(option))")
        .accessibilityAddTraits(selected == option ? [.isSelected] : [])
    }

    /// a11y id 用无空格形式:off / 10min / 30min ...
    private func identifier(_ option: StaleThreshold) -> String {
        switch option {
        case .off: return "off"
        case .minutes(let m): return "\(m)min"
        }
    }
}
