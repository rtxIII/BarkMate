//
//  AlertSoundPickerView.swift
//  BarkAgent
//
//  声音选择屏。全局默认 + 三个可覆盖 status。点击 = 选中 + 试听。
//

import SwiftUI
import Factory
import Models
import Store
import DesignSystem

struct AlertSoundPickerView: View {

    @Injected(\.alertSoundStore) private var store: AlertSoundStore

    // 触发重绘:选中态存在 store(UserDefaults),用本地镜像驱动 UI。
    @State private var globalID: String = SoundCatalog.systemDefaultID
    @State private var overrides: [AgentStatus: String] = [:]
    // 当前正在为哪个 status 选择;nil = 选择全局默认。
    @State private var editingStatus: AgentStatus? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                MCConsoleHeader(
                    crumbs: ["SYS", "SETTINGS", "SOUND"],
                    title: "Alert sound"
                )
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 0) {
                    MCSectionHeader("Default", trailing: "global")
                    ForEach(SoundCatalog.all) { sound in
                        soundRow(sound, selectedID: globalID, status: nil)
                    }

                    MCSectionHeader("Per-status", trailing: "override")
                    ForEach(AlertSoundStore.overridableStatuses, id: \.self) { status in
                        statusRow(status)
                    }

                    if let editingStatus {
                        MCSectionHeader(
                            statusLabel(editingStatus),
                            trailing: "pick"
                        )
                        useDefaultRow(for: editingStatus)
                        ForEach(SoundCatalog.barkSounds) { sound in
                            soundRow(
                                sound,
                                selectedID: overrides[editingStatus],
                                status: editingStatus
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .mcScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("alert-sound-picker")
        .onAppear(perform: loadState)
    }

    // MARK: - Rows

    private func soundRow(_ sound: AlertSound, selectedID: String?, status: AgentStatus?) -> some View {
        Button {
            select(sound: sound, for: status)
        } label: {
            MCSettingRow(title: sound.displayName) {
                MCSettingValue(
                    selectedID == sound.id ? "✓" : "",
                    tone: .accent
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(status == nil ? "sound-row-\(sound.id)" : "sound-row-\(status!.rawValue)-\(sound.id)")
        .accessibilityAddTraits(selectedID == sound.id ? [.isSelected] : [])
    }

    private func statusRow(_ status: AgentStatus) -> some View {
        Button {
            editingStatus = (editingStatus == status) ? nil : status
        } label: {
            MCSettingRow(
                title: statusLabel(status),
                detail: nil
            ) { MCSettingValue(overrideLabel(status)) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("status-row-\(status.rawValue)")
    }

    private func useDefaultRow(for status: AgentStatus) -> some View {
        Button {
            store.setOverride(id: nil, for: status)
            overrides[status] = nil
        } label: {
            MCSettingRow(title: "Use default") {
                MCSettingValue(overrides[status] == nil ? "✓" : "", tone: .accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sound-row-\(status.rawValue)-default")
    }

    // MARK: - Actions

    private func select(sound: AlertSound, for status: AgentStatus?) {
        if let status {
            store.setOverride(id: sound.id, for: status)
            overrides[status] = sound.id
        } else {
            store.setGlobalDefault(id: sound.id)
            globalID = sound.id
        }
        SoundPreviewPlayer.shared.play(fileName: sound.fileName)
    }

    private func loadState() {
        globalID = store.globalDefaultID() ?? SoundCatalog.systemDefaultID
        var map: [AgentStatus: String] = [:]
        for status in AlertSoundStore.overridableStatuses {
            if let id = store.overrideID(for: status) { map[status] = id }
        }
        overrides = map
    }

    // MARK: - Labels

    private func statusLabel(_ status: AgentStatus) -> String {
        switch status {
        case .waitingInput: return "Waiting input"
        case .blocked: return "Blocked"
        case .failed: return "Failed"
        default: return status.rawValue
        }
    }

    private func overrideLabel(_ status: AgentStatus) -> String {
        guard
            let id = overrides[status],
            let sound = SoundCatalog.sound(for: id)
        else { return "default" }
        return sound.displayName.lowercased()
    }
}
