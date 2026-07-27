//
//  BarkMateWidgets.swift
//  BarkMateWidgets
//
//  v0.4 真功能版:Active Agents 摘要 widget。
//
//  Small 尺寸:三栏数字 needsYou / running / settled。
//  Medium 尺寸:三栏数字 + 最近一个 needsYou agent 名 + status code。
//  accessoryRectangular:锁屏矩形,三桶计数摘要(系统单色染色,靠数字大小/位置区分)。
//
//  数据源:via SharedModelContainer 读 SwiftData 同一 store。
//  Widget timeline 每 10 分钟刷新一次,UI 改动由主 app 触发 reloadAllTimelines。
//

import WidgetKit
import SwiftUI
import SwiftData
import Models
import Store
import DesignSystem

@main
struct BarkAgentWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ActiveAgentsWidget()
        AgentLiveActivity()   // 线 C:LA 与普通 widget 同 bundle
    }
}

// MARK: - Configuration

struct ActiveAgentsWidget: Widget {
    let kind: String = WidgetKind.activeAgents

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActiveAgentsProvider()) { entry in
            ActiveAgentsWidgetView(entry: entry)
        }
        .configurationDisplayName("Active agents")
        .description("Live triage of agents needing you, running, or settled.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Entry

struct ActiveAgentsEntry: TimelineEntry {
    let date: Date
    let counts: BucketCounts
    let topNeedsYou: AgentDigest?

    static let placeholder = ActiveAgentsEntry(
        date: .now,
        counts: BucketCounts(needsYou: 2, running: 3, settled: 1),
        topNeedsYou: AgentDigest(
            agentName: "test-writer",
            statusCode: "[ WAIT ]",
            statusColorHex: 0xFFB000,
            latestStep: "Confirm overwrite existing mocks"
        )
    )
}

struct BucketCounts: Equatable, Sendable {
    let needsYou: Int
    let running: Int
    let settled: Int

    static let zero = BucketCounts(needsYou: 0, running: 0, settled: 0)
}

struct AgentDigest: Equatable, Sendable {
    let agentName: String
    let statusCode: String
    let statusColorHex: UInt
    let latestStep: String
}

// MARK: - Provider

struct ActiveAgentsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActiveAgentsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ActiveAgentsEntry) -> Void) {
        completion(snapshot())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveAgentsEntry>) -> Void) {
        let entry = snapshot()
        let nextRefresh = Date.now.addingTimeInterval(10 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func snapshot() -> ActiveAgentsEntry {
        guard let container = try? SharedModelContainer.make() else {
            return ActiveAgentsEntry(date: .now, counts: .zero, topNeedsYou: nil)
        }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AgentTask>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        guard let tasks = try? context.fetch(descriptor) else {
            return ActiveAgentsEntry(date: .now, counts: .zero, topNeedsYou: nil)
        }

        var needsYou = 0, running = 0, settled = 0
        var firstNeedsYou: AgentTask?
        for task in tasks {
            switch task.status.mcBucket {
            case .needsYou:
                needsYou += 1
                if firstNeedsYou == nil { firstNeedsYou = task }
            case .running:
                running += 1
            case .settled:
                settled += 1
            }
        }

        let digest = firstNeedsYou.map { task in
            AgentDigest(
                agentName: task.displayName,
                statusCode: task.status.mcCode,
                statusColorHex: task.status == .waitingInput ? 0xFFB000 : 0xFF6B35,
                latestStep: task.latestStepTitle ?? ""
            )
        }

        return ActiveAgentsEntry(
            date: .now,
            counts: BucketCounts(needsYou: needsYou, running: running, settled: settled),
            topNeedsYou: digest
        )
    }
}

// MARK: - Views

struct ActiveAgentsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ActiveAgentsEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                // accessory 锁屏由系统做单色染色 + 材质背景,widget 自身不铺不透明底色
                family == .accessoryRectangular ? Color.clear : MissionControl.Color.background
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .systemSmall: smallBody
        case .systemMedium: mediumBody
        case .accessoryRectangular: accessoryRectBody
        default: smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            crumbHeader
            Spacer(minLength: 0)
            countsRow
        }
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            crumbHeader
            countsRow
            Spacer(minLength: 0)
            if let digest = entry.topNeedsYou {
                topAgentRow(digest)
            } else {
                Text("— ALL CLEAR —")
                    .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(MissionControl.Color.inkSoft)
            }
        }
    }

    private var crumbHeader: some View {
        HStack(spacing: 4) {
            Text("OPS")
                .foregroundStyle(MissionControl.Color.inkSoft)
            Text("/")
                .foregroundStyle(MissionControl.Color.ruleHot)
            Text("TODAY")
                .foregroundStyle(MissionControl.Color.amber)
        }
        .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
        .tracking(1.2)
    }

    private var countsRow: some View {
        HStack(spacing: 8) {
            countCell(entry.counts.needsYou,
                      label: "NEEDS YOU",
                      color: MissionControl.Color.amber,
                      highlighted: entry.counts.needsYou > 0)
            countCell(entry.counts.running,
                      label: "RUNNING",
                      color: MissionControl.Color.cyan)
            countCell(entry.counts.settled,
                      label: "DONE",
                      color: MissionControl.Color.inkMute)
        }
    }

    private func countCell(_ n: Int, label: String, color: Color, highlighted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(format(n))
                .font(MissionControl.Font.interTight(size: 26, weight: .black))
                .tracking(-1.0)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(MissionControl.Font.jetBrainsMono(size: 7.5, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(MissionControl.Color.inkSoft)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MissionControl.Color.void)
        .overlay(
            Rectangle()
                .stroke(highlighted ? color : MissionControl.Color.rule,
                        lineWidth: MissionControl.Border.hairline)
        )
    }

    private func topAgentRow(_ digest: AgentDigest) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(digest.statusCode)
                    .font(MissionControl.Font.jetBrainsMono(size: 8.5, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: digest.statusColorHex))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .overlay(
                        Rectangle()
                            .stroke(Color(hex: digest.statusColorHex),
                                    lineWidth: MissionControl.Border.hairline)
                    )
                Text(digest.agentName)
                    .font(MissionControl.Font.interTight(size: 12, weight: .bold))
                    .tracking(-0.24)
                    .foregroundStyle(MissionControl.Color.ink)
                    .lineLimit(1)
            }
            if !digest.latestStep.isEmpty {
                Text(digest.latestStep)
                    .font(MissionControl.Font.jetBrainsMono(size: 9.5, weight: .regular))
                    .foregroundStyle(MissionControl.Color.inkSoft)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 锁屏 accessoryRectangular:系统单色染色渲染,不使用 HUD 多色(amber/cyan/lime),
    // 靠数字大小 + WAIT/RUN/DONE 位置区分三桶。counts 行标 accentable 取用户锁屏染色。
    private var accessoryRectBody: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("BARKMATE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.0)
            HStack(spacing: 6) {
                accessoryCount(entry.counts.needsYou, "WAIT")
                accessoryCount(entry.counts.running, "RUN")
                accessoryCount(entry.counts.settled, "DONE")
            }
            .widgetAccentable()
            if let digest = entry.topNeedsYou {
                Text("\(digest.agentName) needs you")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func accessoryCount(_ n: Int, _ label: String) -> some View {
        HStack(spacing: 2) {
            Text(format(n))
                .font(.system(size: 15, weight: .bold))
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func format(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    ActiveAgentsWidget()
} timeline: {
    ActiveAgentsEntry.placeholder
    ActiveAgentsEntry(date: .now, counts: .zero, topNeedsYou: nil)
}

#Preview(as: .systemMedium) {
    ActiveAgentsWidget()
} timeline: {
    ActiveAgentsEntry.placeholder
}

#Preview(as: .accessoryRectangular) {
    ActiveAgentsWidget()
} timeline: {
    ActiveAgentsEntry.placeholder
    ActiveAgentsEntry(date: .now, counts: .zero, topNeedsYou: nil)
}
