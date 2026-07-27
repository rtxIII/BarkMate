//
//  AgentLiveActivity.swift
//  BarkMateWidgets
//
//  线 C(本地链 P0):Live Activity UI,与普通 Widget 同处一个 bundle(不新开 target)。
//  锁屏 LA 卡 + Dynamic Island(compact / minimal / expanded 三区),配色走 MissionControl。
//  约束:compact/minimal 只放 status glyph + 进度;expanded 才展开 step 详情。
//

#if os(iOS)
import ActivityKit
import WidgetKit
import SwiftUI
import Models
import DesignSystem

struct AgentLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AgentActivityAttributes.self) { context in
            AgentLiveActivityLockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .padding(14)
            .activityBackgroundTint(MissionControl.Color.hull)
            .activitySystemActionForegroundColor(MissionControl.Color.ink)
        } dynamicIsland: { context in
            let status = context.state.status
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text("◆").foregroundStyle(status.mcColor)
                        Text(context.attributes.displayName)
                            .font(MissionControl.Font.interTight(size: 14, weight: .bold))
                            .foregroundStyle(MissionControl.Color.ink)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatusBadge(status: status, style: .missionControl)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.stepTitle)
                            .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                            .foregroundStyle(MissionControl.Color.inkSoft)
                            .lineLimit(2)
                        if let progress = context.state.progress {
                            Text(progress)
                                .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
                                .foregroundStyle(status.mcColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Text("◆").foregroundStyle(status.mcColor)
            } compactTrailing: {
                if let progress = context.state.progress {
                    Text(progress)
                        .font(MissionControl.Font.jetBrainsMono(size: 12, weight: .bold))
                        .foregroundStyle(status.mcColor)
                        .lineLimit(1)
                }
            } minimal: {
                Text("◆").foregroundStyle(status.mcColor)
            }
        }
    }
}

/// 锁屏 / 横幅态 LA 卡:左状态色 accent 条 + 名称 + StatusBadge + step + 进度。
struct AgentLiveActivityLockScreenView: View {
    let attributes: AgentActivityAttributes
    let state: AgentActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(state.status.mcColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("◆").foregroundStyle(state.status.mcColor)
                    Text(attributes.displayName)
                        .font(MissionControl.Font.interTight(size: 17, weight: .heavy))
                        .tracking(-0.34)
                        .foregroundStyle(MissionControl.Color.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    StatusBadge(status: state.status, style: .missionControl)
                }
                Text(state.stepTitle)
                    .font(MissionControl.Font.jetBrainsMono(size: 11.5, weight: .regular))
                    .foregroundStyle(MissionControl.Color.inkSoft)
                    .lineLimit(2)
                if let progress = state.progress {
                    Text(progress)
                        .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(state.status.mcColor)
                }
            }
        }
    }
}

// MARK: - Preview

extension AgentActivityAttributes {
    fileprivate static var preview: AgentActivityAttributes {
        AgentActivityAttributes(agentID: "test-writer", displayName: "test-writer")
    }
}

extension AgentActivityAttributes.ContentState {
    fileprivate static var waiting: AgentActivityAttributes.ContentState {
        .init(status: .waitingInput, stepTitle: "Confirm overwrite existing mocks", progress: "3/7")
    }
    fileprivate static var running: AgentActivityAttributes.ContentState {
        .init(status: .running, stepTitle: "migrate · applying 0042_add_index", progress: "4/6")
    }
}

#Preview("Lock screen", as: .content, using: AgentActivityAttributes.preview) {
    AgentLiveActivity()
} contentStates: {
    AgentActivityAttributes.ContentState.waiting
    AgentActivityAttributes.ContentState.running
}
#endif
