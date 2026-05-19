//
//  AgentMockPrototypeView.swift
//  BarkMate
//
//  SwiftUI mock prototype for the v0.3 Agent Dashboard direction.
//  This file intentionally uses local mock structs instead of SwiftData so the
//  interaction and visual density can be evaluated before Phase 2 data plumbing.
//

import SwiftUI

struct AgentMockPrototypeView: View {
    var body: some View {
        TabView {
            NavigationStack {
                AgentMockDashboardView()
            }
            .tabItem { Label("Agents", systemImage: "rectangle.grid.2x2") }

            NavigationStack {
                AgentMockSearchView()
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                AgentMockSetupView()
            }
            .tabItem { Label("Setup", systemImage: "terminal") }

            NavigationStack {
                AgentMockHistoryView()
            }
            .tabItem { Label("History", systemImage: "clock") }

            NavigationStack {
                AgentMockSettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(MockPalette.ink)
    }
}

// MARK: - Dashboard

private struct AgentMockDashboardView: View {
    @State private var selectedFilter: AgentFilter = .all
    @State private var tasks: [MockAgentTask] = MockData.tasks

    private var filteredTasks: [MockAgentTask] {
        tasks
            .filter { selectedFilter.matches($0) }
            .sorted(by: MockAgentTask.prioritySort)
    }

    private var counts: AgentCounts { AgentCounts(tasks: tasks) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                AgentHeroCard(counts: counts)

                FilterStrip(selected: $selectedFilter)

                SectionTitle("Active Agents", trailing: "\(filteredTasks.count) cards")

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    ForEach(filteredTasks) { task in
                        NavigationLink {
                            AgentMockDetailView(task: task)
                        } label: {
                            AgentTaskCard(task: task)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        simulatePush()
                    } label: {
                        Label("Demo push", systemImage: "bolt.fill")
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle())

                    Button("Reconcile stale") {}
                        .buttonStyle(SecondaryCapsuleButtonStyle())
                }

                SectionTitle("History", trailing: "old Bark + memos")

                VStack(spacing: 10) {
                    ForEach(MockData.history.prefix(3)) { item in
                        HistoryMiniRow(item: item)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .background(MockScreenBackground())
        .navigationTitle("Agents")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { simulatePush() } label: {
                    Image(systemName: "bolt.badge.clock")
                }
                .accessibilityLabel("Send demo push")
            }
        }
    }

    private func simulatePush() {
        guard let index = tasks.firstIndex(where: { $0.id == "backend-refactor" }) else { return }
        var task = tasks[index]
        let nextStep = min(8, task.completedSteps + 1)
        task.completedSteps = nextStep
        task.latestStep = nextStep >= 8 ? "Backend refactor complete" : "Patched middleware tests"
        task.status = nextStep >= 8 ? .done : .running
        task.updatedLabel = "now"
        task.steps.insert(
            MockAgentStep(
                time: "10:\(32 + nextStep)",
                status: task.status,
                title: task.latestStep,
                body: "Demo push used the same agent_id + task_id, so the existing card updated in place."
            ),
            at: 0
        )
        tasks[index] = task
    }
}

private struct AgentHeroCard: View {
    let counts: AgentCounts

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Live agent map")
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.58))
                    Text("\(counts.running) running · \(counts.waiting) waiting · \(counts.blocked) blocked")
                        .font(.custom("Iowan Old Style", size: 26).weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(counts.active)")
                    .font(.custom("Iowan Old Style", size: 68).weight(.bold))
                    .tracking(-5)
                    .foregroundStyle(.white)
            }

            HStack(spacing: 9) {
                MiniStat(value: counts.failed, label: "failed")
                MiniStat(value: counts.stale, label: "stale")
                MiniStat(value: counts.done, label: "done")
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [MockPalette.ink, Color(hex: 0x273843)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(MockPalette.yellow.opacity(0.34))
                        .frame(width: 170, height: 170)
                        .blur(radius: 12)
                        .offset(x: 62, y: -76)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: MockPalette.ink.opacity(0.18), radius: 24, x: 0, y: 14)
    }
}

private struct MiniStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(.white.opacity(0.11), lineWidth: 1)
        )
    }
}

private struct FilterStrip: View {
    @Binding var selected: AgentFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AgentFilter.allCases) { filter in
                    Button(filter.title) { selected = filter }
                        .buttonStyle(ChipButtonStyle(isSelected: selected == filter))
                }
            }
        }
    }
}

private struct AgentTaskCard: View {
    let task: MockAgentTask

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                AgentAvatar(text: task.initials)
                Spacer()
                StatusBadge(status: task.status, compact: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.agentName)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(MockPalette.ink)
                    .lineLimit(1)
                Text(task.taskID)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(MockPalette.ink.opacity(0.48))
                    .lineLimit(1)
            }

            Text(task.latestStep)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MockPalette.ink.opacity(0.72))
                .lineLimit(2)
                .frame(minHeight: 34, alignment: .topLeading)

            ProgressView(value: task.progressFraction)
                .tint(task.status.color)
                .background(MockPalette.ink.opacity(0.08), in: Capsule())

            HStack {
                Text("\(task.progressLabel) · \(task.updatedLabel)")
                Spacer()
                if task.isMuted { Image(systemName: "bell.slash.fill") }
                if task.isPinned { Image(systemName: "pin.fill") }
            }
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(MockPalette.ink.opacity(0.45))
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(MockPalette.paperHot.opacity(0.82))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(task.status.color)
                        .frame(width: 5)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(task.status.color.opacity(0.18))
                        .frame(width: 112, height: 112)
                        .offset(x: 48, y: -50)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MockPalette.ink.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: MockPalette.ink.opacity(0.08), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Detail

private struct AgentMockDetailView: View {
    let task: MockAgentTask
    @State private var summaryState: SummaryState = .ready

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                DetailHero(task: task)

                HStack(spacing: 9) {
                    Button("Pin") {}
                    Button("Mute") {}
                    Button("Archive") {}
                    Button("Mark done") {}
                        .tint(MockPalette.red)
                }
                .buttonStyle(SecondaryCapsuleButtonStyle())
                .font(.caption.weight(.heavy))

                SummaryPanel(task: task, state: summaryState) {
                    withAnimation(.easeInOut(duration: 0.2)) { summaryState = .loading }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeInOut(duration: 0.2)) { summaryState = .generated }
                    }
                }

                SectionTitle("Step History", trailing: "\(task.steps.count) pushes")

                VStack(spacing: 10) {
                    ForEach(task.steps) { step in
                        StepRow(step: step)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .background(MockScreenBackground())
        .navigationTitle("Agent detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailHero: View {
    let task: MockAgentTask

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatusBadge(status: task.status, compact: false)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.agentName)
                    .font(.custom("Iowan Old Style", size: 36).weight(.bold))
                    .tracking(-2)
                    .foregroundStyle(.white)
                Text(task.taskID)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
            }

            HStack(spacing: 9) {
                DetailMetric(value: task.progressLabel, label: "progress")
                DetailMetric(value: task.etaLabel, label: "eta")
                DetailMetric(value: task.updatedLabel, label: "updated")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [MockPalette.ink, Color(hex: 0x273843)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(task.status.color.opacity(0.45))
                        .frame(width: 180, height: 180)
                        .blur(radius: 10)
                        .offset(x: 72, y: -84)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: MockPalette.ink.opacity(0.18), radius: 24, x: 0, y: 14)
    }
}

private struct DetailMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.56))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.11), lineWidth: 1))
    }
}

private struct SummaryPanel: View {
    let task: MockAgentTask
    let state: SummaryState
    let summarize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("On-device progress summary")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(MockPalette.ink.opacity(0.54))
                Spacer()
                if state == .ready {
                    Button("Summarize", action: summarize)
                        .buttonStyle(PrimaryCapsuleButtonStyle(compact: true))
                } else if state == .generated {
                    Text("cached · 5m")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(MockPalette.ink.opacity(0.50))
                }
            }

            switch state {
            case .ready:
                Text("点击按钮后模拟本地摘要。真实版本会在支持设备上调用 Apple Intelligence，不支持时仍显示原始 step。")
                    .summaryTextStyle()
            case .loading:
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonLine(width: 1.0)
                    SkeletonLine(width: 0.72)
                    SkeletonLine(width: 0.48)
                }
            case .generated:
                Text(task.summary)
                    .summaryTextStyle()
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [MockPalette.paperHot.opacity(0.94), MockPalette.paperDeep.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(MockPalette.ink.opacity(0.10), lineWidth: 1))
        .shadow(color: MockPalette.ink.opacity(0.06), radius: 14, x: 0, y: 7)
    }
}

private struct StepRow: View {
    let step: MockAgentStep

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step.time)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(MockPalette.ink.opacity(0.48))
                .frame(width: 42, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                StatusBadge(status: step.status, compact: true)
                Text(step.title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(MockPalette.ink)
                Text(step.body)
                    .font(.system(size: 12, weight: .medium))
                    .lineSpacing(2)
                    .foregroundStyle(MockPalette.ink.opacity(0.58))
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(MockPalette.paperHot.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(MockPalette.ink.opacity(0.10), lineWidth: 1))
    }
}

// MARK: - Setup

private struct AgentMockSetupView: View {
    private let curl = """
    curl -X POST "https://api.day.app/<key>" \\
      -d "group=backend-refactor" \\
      -d "task_id=auth-migration-0420" \\
      -d "agent_status=running" \\
      -d "progress=3/8" \\
      -d "title=Refactoring auth middleware"
    """

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                SetupHero()

                VStack(alignment: .leading, spacing: 12) {
                    Pill("curl template")
                    Text(curl)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: 0xEAF0E9))
                        .lineSpacing(3)
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MockPalette.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    HStack(spacing: 10) {
                        Button("Copy curl") {}
                            .buttonStyle(PrimaryCapsuleButtonStyle())
                        Button("Send demo push") {}
                            .buttonStyle(SecondaryCapsuleButtonStyle())
                    }
                }
                .mockCardPadding()

                VStack(alignment: .leading, spacing: 8) {
                    Text("关键字段")
                        .font(.headline.weight(.heavy))
                    FieldExplainer(name: "group", value: "agent_id")
                    FieldExplainer(name: "task_id", value: "同一任务的聚合键")
                    FieldExplainer(name: "agent_status", value: "running / waiting_input / blocked / done / failed")
                    FieldExplainer(name: "progress", value: "3/7 或 45%")
                }
                .mockCardPadding()

                VStack(alignment: .leading, spacing: 6) {
                    Text("旧 Bark 兼容")
                        .font(.headline.weight(.heavy))
                    Text("不带 agent_status 的推送会进入 History Timeline，不会污染 Active Agents。")
                        .font(.subheadline)
                        .foregroundStyle(MockPalette.ink.opacity(0.62))
                }
                .mockCardPadding()
            }
            .padding(18)
            .padding(.bottom, 30)
        }
        .background(MockScreenBackground())
        .navigationTitle("Setup")
    }
}

private struct SetupHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Pill("first push", dark: true)
            Text("Send one push. Get one living card.")
                .font(.custom("Iowan Old Style", size: 36).weight(.bold))
                .tracking(-2)
                .foregroundStyle(.white)
            Text("带上 agent_status 和 task_id，同一个任务会原地更新，而不是堆成消息流。")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.66))
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [MockPalette.ink, Color(hex: 0x273843)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(MockPalette.yellow.opacity(0.34))
                        .frame(width: 170, height: 170)
                        .blur(radius: 12)
                        .offset(x: 62, y: -76)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

private struct FieldExplainer: View {
    let name: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(MockPalette.blue)
                .frame(width: 104, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MockPalette.ink.opacity(0.68))
        }
    }
}

// MARK: - Search

private struct AgentMockSearchView: View {
    @State private var query: String = "mock"
    @State private var selectedScope: SearchScope = .all

    private var results: [MockSearchResult] {
        MockData.searchResults.filter { result in
            selectedScope.matches(result) &&
                (query.isEmpty || result.searchText.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Search agents, steps, memos", text: $query)
                    .textFieldStyle(MockSearchFieldStyle())

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SearchScope.allCases) { scope in
                            Button(scope.title) { selectedScope = scope }
                                .buttonStyle(ChipButtonStyle(isSelected: selectedScope == scope))
                        }
                    }
                }

                HStack(spacing: 8) {
                    Pill("status: waiting")
                    Pill("server: all")
                    Pill("last 7d")
                }

                VStack(spacing: 10) {
                    ForEach(results) { result in
                        SearchResultRow(result: result, query: query)
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 30)
        }
        .background(MockScreenBackground())
        .navigationTitle("Search")
    }
}

private struct SearchResultRow: View {
    let result: MockSearchResult
    let query: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Pill(result.kind.rawValue)
                HighlightedMockText(result.title, highlight: query)
                    .font(.headline.weight(.heavy))
                HighlightedMockText(result.body, highlight: query)
                    .font(.subheadline)
                    .foregroundStyle(MockPalette.ink.opacity(0.60))
            }
            Spacer()
            if let status = result.status {
                StatusBadge(status: status, compact: true)
            }
        }
        .mockCardPadding()
    }
}

private struct HighlightedMockText: View {
    let text: String
    let highlight: String

    init(_ text: String, highlight: String) {
        self.text = text
        self.highlight = highlight.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if highlight.isEmpty {
            Text(text)
        } else if let range = text.range(of: highlight, options: .caseInsensitive) {
            Text(text[..<range.lowerBound]) +
                Text(text[range]).foregroundStyle(MockPalette.blue).bold() +
                Text(text[range.upperBound...])
        } else {
            Text(text)
        }
    }
}

// MARK: - History

private struct AgentMockHistoryView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HistoryHero()

                HStack(spacing: 8) {
                    Pill("All")
                    Pill("Archived agents")
                    Pill("Incoming")
                    Pill("Memos")
                }

                VStack(spacing: 10) {
                    ForEach(MockData.history) { item in
                        HistoryRow(item: item)
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 30)
        }
        .background(MockScreenBackground())
        .navigationTitle("History")
    }
}

private struct HistoryHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Pill("timeline", dark: true)
            Text("Messages become context, not noise.")
                .font(.custom("Iowan Old Style", size: 34).weight(.bold))
                .tracking(-2)
                .foregroundStyle(.white)
            Text("旧协议推送、归档 task 和 memo 都在这里追溯。")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.66))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [MockPalette.ink, Color(hex: 0x273843)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

private struct HistoryRow: View {
    let item: MockHistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.headline.weight(.heavy))
                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(MockPalette.ink.opacity(0.58))
            }
            Spacer()
            Pill(item.kind)
        }
        .mockCardPadding()
    }
}

private struct HistoryMiniRow: View {
    let item: MockHistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 13, weight: .heavy))
                Text(item.body)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MockPalette.ink.opacity(0.58))
                    .lineLimit(2)
            }
            Spacer()
            Pill(item.kind)
        }
        .mockCardPadding()
    }
}

// MARK: - Settings

private struct AgentMockSettingsView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Servers", trailing: "2 online")
                SettingRow(title: "api.day.app", detailText: "Default server · key synced", badge: "online")
                SettingRow(title: "barkmate.we2.xyz", detailText: "Worker · v0.3 fields passthrough", badge: "online")

                SectionTitle("Agent behavior", trailing: "defaults")
                SettingRow(title: "Stale timeout", detailText: "Running tasks become stale after 30 minutes.", badge: "30m")
                SettingToggleRow(title: "On-device summary", detailText: "Use Apple Intelligence when available.")
                SettingToggleRow(title: "Time Sensitive alerts", detailText: "waiting_input, blocked and failed can break through quiet mode.")
                SettingRow(title: "Privacy", detailText: "No analytics. Summary prompts never leave iPhone.", badge: "local")

                SectionTitle("Live Activity concept", trailing: "V1.1")
                LiveActivityMockCard()
            }
            .padding(18)
            .padding(.bottom, 30)
        }
        .background(MockScreenBackground())
        .navigationTitle("Settings")
    }
}

private struct SettingRow: View {
    let title: String
    let detailText: String
    let badge: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.heavy))
                Text(detailText)
                    .font(.subheadline)
                    .foregroundStyle(MockPalette.ink.opacity(0.58))
            }
            Spacer()
            Pill(badge)
        }
        .mockCardPadding()
    }
}

private struct SettingToggleRow: View {
    let title: String
    let detailText: String
    @State private var isOn: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.heavy))
                Text(detailText)
                    .font(.subheadline)
                    .foregroundStyle(MockPalette.ink.opacity(0.58))
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(MockPalette.ink)
        }
        .mockCardPadding()
    }
}

private struct LiveActivityMockCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                AgentAvatar(text: "TW")
                VStack(alignment: .leading, spacing: 2) {
                    Text("test-writer needs confirmation")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                    Text("Confirm overwrite existing mocks · 4/7 complete")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                StatusBadge(status: .waitingInput, compact: true)
            }
            ProgressView(value: 4.0 / 7.0)
                .tint(MockPalette.yellow)
        }
        .padding(15)
        .background(
            LinearGradient(colors: [MockPalette.ink, Color(hex: 0x273843)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }
}

// MARK: - Shared UI

private struct SectionTitle: View {
    let title: String
    let trailing: String

    init(_ title: String, trailing: String) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.1)
            Spacer()
            Text(trailing)
                .font(.caption.weight(.bold))
                .foregroundStyle(MockPalette.ink.opacity(0.50))
        }
        .padding(.top, 2)
    }
}

private struct AgentAvatar: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(MockPalette.ink, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct StatusBadge: View {
    let status: MockAgentStatus
    let compact: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            Text(status.label)
        }
        .font(.system(size: compact ? 8 : 10, weight: .heavy))
        .tracking(0.5)
        .textCase(.uppercase)
        .foregroundStyle(status.color)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 5 : 7)
        .background(status.color.opacity(0.13), in: Capsule())
        .overlay(Capsule().stroke(status.color.opacity(0.28), lineWidth: 1))
    }
}

private struct Pill: View {
    let text: String
    let dark: Bool

    init(_ text: String, dark: Bool = false) {
        self.text = text
        self.dark = dark
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.7)
            .foregroundStyle(dark ? .white.opacity(0.72) : MockPalette.ink.opacity(0.58))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(dark ? .white.opacity(0.12) : MockPalette.ink.opacity(0.08), in: Capsule())
    }
}

private struct MockScreenBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xFFF8EB), Color(hex: 0xF1E7D6), Color(hex: 0xE7DAC8)],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(MockPalette.yellow.opacity(0.20))
                .frame(width: 240, height: 240)
                .blur(radius: 28)
                .offset(x: -170, y: -360)
            Circle()
                .fill(MockPalette.cyan.opacity(0.15))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: 160, y: -330)
        }
        .ignoresSafeArea()
    }
}

private struct SkeletonLine: View {
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 999)
            .fill(
                LinearGradient(
                    colors: [MockPalette.ink.opacity(0.07), MockPalette.ink.opacity(0.16), MockPalette.ink.opacity(0.07)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 11)
            .scaleEffect(x: width, y: 1, anchor: .leading)
    }
}

private struct PrimaryCapsuleButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 11 : 12, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 10 : 13)
            .padding(.vertical, compact ? 7 : 10)
            .background(MockPalette.ink, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct SecondaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(MockPalette.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(MockPalette.paperHot.opacity(0.72), in: Capsule())
            .overlay(Capsule().stroke(MockPalette.ink.opacity(0.12), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(isSelected ? .white : MockPalette.ink.opacity(0.68))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? MockPalette.ink : MockPalette.paperHot.opacity(0.72), in: Capsule())
            .overlay(Capsule().stroke(MockPalette.ink.opacity(isSelected ? 0 : 0.12), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct MockSearchFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.body.weight(.bold))
            .padding(14)
            .background(MockPalette.paperHot.opacity(0.80), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 21).stroke(MockPalette.ink.opacity(0.12), lineWidth: 1))
            .shadow(color: MockPalette.ink.opacity(0.07), radius: 14, x: 0, y: 7)
    }
}

private extension View {
    func mockCardPadding() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MockPalette.paperHot.opacity(0.76), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(MockPalette.ink.opacity(0.10), lineWidth: 1))
            .shadow(color: MockPalette.ink.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    func summaryTextStyle() -> some View {
        self
            .font(.system(size: 13, weight: .medium))
            .lineSpacing(3)
            .foregroundStyle(MockPalette.ink.opacity(0.76))
    }
}

// MARK: - Mock data

private enum MockPalette {
    static let ink = Color(hex: 0x121A20)
    static let paperHot = Color(hex: 0xFFF8EC)
    static let paperDeep = Color(hex: 0xE2D4BF)
    static let blue = Color(hex: 0x246BFE)
    static let yellow = Color(hex: 0xEAB33D)
    static let orange = Color(hex: 0xEE6F2F)
    static let green = Color(hex: 0x2CA462)
    static let red = Color(hex: 0xD94735)
    static let gray = Color(hex: 0x737B71)
    static let cyan = Color(hex: 0x1EA5B5)
}

private enum MockAgentStatus: String, Hashable, CaseIterable {
    case running
    case waitingInput
    case blocked
    case done
    case failed
    case stale

    var label: String {
        switch self {
        case .running: "running"
        case .waitingInput: "waiting"
        case .blocked: "blocked"
        case .done: "done"
        case .failed: "failed"
        case .stale: "stale"
        }
    }

    var color: Color {
        switch self {
        case .running: MockPalette.blue
        case .waitingInput: MockPalette.yellow
        case .blocked: MockPalette.orange
        case .done: MockPalette.green
        case .failed: MockPalette.red
        case .stale: MockPalette.gray
        }
    }

    var sortPriority: Int {
        switch self {
        case .waitingInput: 1
        case .blocked: 2
        case .failed: 3
        case .running: 4
        case .stale: 5
        case .done: 6
        }
    }
}

private struct MockAgentTask: Identifiable, Hashable {
    let id: String
    let agentName: String
    let taskID: String
    var status: MockAgentStatus
    var completedSteps: Int
    let totalSteps: Int
    var latestStep: String
    var updatedLabel: String
    let etaLabel: String
    let source: String
    let isPinned: Bool
    let isMuted: Bool
    let summary: String
    var steps: [MockAgentStep]

    var initials: String {
        agentName
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
    }

    var progressLabel: String { "\(completedSteps)/\(totalSteps)" }
    var progressFraction: Double { Double(completedSteps) / Double(max(totalSteps, 1)) }

    static func prioritySort(_ lhs: MockAgentTask, _ rhs: MockAgentTask) -> Bool {
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
        if lhs.status.sortPriority != rhs.status.sortPriority { return lhs.status.sortPriority < rhs.status.sortPriority }
        return lhs.agentName < rhs.agentName
    }
}

private struct MockAgentStep: Identifiable, Hashable {
    let id = UUID()
    let time: String
    let status: MockAgentStatus
    let title: String
    let body: String
}

private struct AgentCounts {
    let running: Int
    let waiting: Int
    let blocked: Int
    let failed: Int
    let stale: Int
    let done: Int
    let active: Int

    init(tasks: [MockAgentTask]) {
        running = tasks.filter { $0.status == .running }.count
        waiting = tasks.filter { $0.status == .waitingInput }.count
        blocked = tasks.filter { $0.status == .blocked }.count
        failed = tasks.filter { $0.status == .failed }.count
        stale = tasks.filter { $0.status == .stale }.count
        done = tasks.filter { $0.status == .done }.count
        active = tasks.filter { $0.status != .done }.count
    }
}

private enum AgentFilter: String, Identifiable, CaseIterable {
    case all
    case attention
    case running
    case blocked
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .attention: "Needs attention"
        case .running: "Running"
        case .blocked: "Blocked"
        case .done: "Done"
        }
    }

    func matches(_ task: MockAgentTask) -> Bool {
        switch self {
        case .all: true
        case .attention: [.waitingInput, .blocked, .failed].contains(task.status)
        case .running: task.status == .running
        case .blocked: task.status == .blocked
        case .done: task.status == .done
        }
    }
}

private enum SummaryState {
    case ready
    case loading
    case generated
}

private struct MockHistoryItem: Identifiable {
    let id = UUID()
    let kind: String
    let title: String
    let body: String
}

private enum SearchKind: String {
    case agent
    case step
    case memo
}

private struct MockSearchResult: Identifiable {
    let id = UUID()
    let kind: SearchKind
    let title: String
    let body: String
    let status: MockAgentStatus?

    var searchText: String { "\(title) \(body)" }
}

private enum SearchScope: String, Identifiable, CaseIterable {
    case all
    case agents
    case steps
    case memos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .agents: "Agents"
        case .steps: "Steps"
        case .memos: "Memos"
        }
    }

    func matches(_ result: MockSearchResult) -> Bool {
        switch self {
        case .all: true
        case .agents: result.kind == .agent
        case .steps: result.kind == .step
        case .memos: result.kind == .memo
        }
    }
}

private enum MockData {
    static let tasks: [MockAgentTask] = [
        MockAgentTask(
            id: "backend-refactor",
            agentName: "backend-refactor",
            taskID: "auth-migration-0420",
            status: .running,
            completedSteps: 3,
            totalSteps: 8,
            latestStep: "Refactoring auth middleware",
            updatedLabel: "now",
            etaLabel: "12m",
            source: "api.day.app",
            isPinned: true,
            isMuted: false,
            summary: "正在重构 auth middleware，已经处理 3/8 个文件。当前没有阻塞，下一步是修复测试中的类型错误。",
            steps: [
                MockAgentStep(time: "10:29", status: .running, title: "Fixing unit tests", body: "Typecheck found two mock signatures that need to be updated."),
                MockAgentStep(time: "10:25", status: .running, title: "Updated auth.ts", body: "Extracted token validation into a smaller middleware function."),
                MockAgentStep(time: "10:23", status: .running, title: "Started backend refactor", body: "SessionStart hook received. Preparing branch and reading auth module.")
            ]
        ),
        MockAgentTask(
            id: "test-writer",
            agentName: "test-writer",
            taskID: "mock-coverage",
            status: .waitingInput,
            completedSteps: 4,
            totalSteps: 7,
            latestStep: "Confirm overwrite existing mocks",
            updatedLabel: "2m",
            etaLabel: "waiting",
            source: "barkmate.we2.xyz",
            isPinned: false,
            isMuted: false,
            summary: "任务已完成 4/7 步，正在等待用户确认是否覆盖现有 mock。当前阻塞点是 confirm 提示，回复 yes 后可以继续生成测试。",
            steps: [
                MockAgentStep(time: "10:31", status: .waitingInput, title: "Confirm overwrite existing mocks", body: "The agent wants to replace existing test doubles in __mocks__."),
                MockAgentStep(time: "10:21", status: .running, title: "Generated new mock factories", body: "Prepared mock factories for API and clock dependencies."),
                MockAgentStep(time: "10:18", status: .running, title: "Scanned test gaps", body: "Found uncovered branches in payment and auth modules.")
            ]
        ),
        MockAgentTask(
            id: "e2e-runner",
            agentName: "e2e-runner",
            taskID: "checkout-flow",
            status: .done,
            completedSteps: 6,
            totalSteps: 6,
            latestStep: "All tests passed",
            updatedLabel: "5m",
            etaLabel: "done",
            source: "api.day.app",
            isPinned: false,
            isMuted: false,
            summary: "Checkout flow 的 6 个 e2e 步骤已经全部通过，耗时 4m12s。没有发现新的阻塞或失败。",
            steps: [
                MockAgentStep(time: "10:19", status: .done, title: "All tests passed", body: "6/6 scenarios passed in 4m12s."),
                MockAgentStep(time: "10:15", status: .running, title: "Running payment case", body: "Payment form and order summary passed."),
                MockAgentStep(time: "10:12", status: .running, title: "Launching browser", body: "Playwright started chromium with mobile viewport.")
            ]
        ),
        MockAgentTask(
            id: "log-analyzer",
            agentName: "log-analyzer",
            taskID: "grafana-query",
            status: .blocked,
            completedSteps: 2,
            totalSteps: 5,
            latestStep: "Missing Grafana token",
            updatedLabel: "7m",
            etaLabel: "blocked",
            source: "ops-bark.local",
            isPinned: true,
            isMuted: false,
            summary: "日志分析已完成查询模板和时间窗口选择，但在第 2/5 步卡住。当前阻塞点是缺少 Grafana token。",
            steps: [
                MockAgentStep(time: "10:14", status: .blocked, title: "Missing Grafana token", body: "GRAFANA_TOKEN is not available in the current shell."),
                MockAgentStep(time: "10:10", status: .running, title: "Collected service names", body: "api-gateway, product-service, otel-collector selected.")
            ]
        ),
        MockAgentTask(
            id: "deploy-bot",
            agentName: "deploy-bot",
            taskID: "prod-release-1520",
            status: .failed,
            completedSteps: 5,
            totalSteps: 6,
            latestStep: "Migration failed on users table",
            updatedLabel: "13m",
            etaLabel: "failed",
            source: "barkmate.we2.xyz",
            isPinned: false,
            isMuted: false,
            summary: "生产发布在 5/6 步失败。失败点是 users 表迁移冲突，需要检查重复索引或回滚 migration。",
            steps: [
                MockAgentStep(time: "10:09", status: .failed, title: "Migration failed on users table", body: "duplicate key value violates unique constraint users_email_idx."),
                MockAgentStep(time: "10:06", status: .running, title: "Run migrations", body: "Applying 202605171520_add_user_flags.sql."),
                MockAgentStep(time: "09:58", status: .running, title: "Build image", body: "Docker image pushed to registry.")
            ]
        ),
        MockAgentTask(
            id: "dependency-updater",
            agentName: "dependency-updater",
            taskID: "weekly-bump",
            status: .stale,
            completedSteps: 1,
            totalSteps: 4,
            latestStep: "Installing packages",
            updatedLabel: "42m",
            etaLabel: "stale",
            source: "api.day.app",
            isPinned: false,
            isMuted: true,
            summary: "任务仍停留在安装依赖阶段，已经 42 分钟没有更新。建议回到终端确认进程是否卡死。",
            steps: [
                MockAgentStep(time: "09:28", status: .running, title: "Installing packages", body: "Package manager is resolving dependency graph."),
                MockAgentStep(time: "09:24", status: .running, title: "Started weekly bump", body: "Checking package manifests.")
            ]
        )
    ]

    static let history: [MockHistoryItem] = [
        MockHistoryItem(kind: "incoming", title: "Build finished", body: "旧 Bark 推送：main branch build completed in 12m32s。"),
        MockHistoryItem(kind: "agent", title: "api-cleanup archived", body: "已归档 task，包含 9 条 step 历史和 1 条失败重试。"),
        MockHistoryItem(kind: "#hook", title: "Hook 接入备注", body: "Claude Code Stop hook 里追加 agent_status=done。"),
        MockHistoryItem(kind: "memo", title: "Deploy preview link", body: "Saved from Share Extension placeholder.")
    ]

    static let searchResults: [MockSearchResult] = [
        MockSearchResult(kind: .agent, title: "test-writer", body: "等待确认是否覆盖现有 mock。", status: .waitingInput),
        MockSearchResult(kind: .step, title: "Generated new mock factories", body: "Prepared mock factories for API and clock dependencies.", status: nil),
        MockSearchResult(kind: .memo, title: "Hook 接入备注", body: "覆盖 mock 时把确认提示推为 waiting_input。", status: nil),
        MockSearchResult(kind: .step, title: "Confirm overwrite existing mocks", body: "The agent wants to replace existing test doubles.", status: .waitingInput)
    ]
}

private extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255.0,
            green: Double((hex >> 8) & 0xff) / 255.0,
            blue: Double(hex & 0xff) / 255.0,
            opacity: alpha
        )
    }
}

#Preview {
    AgentMockPrototypeView()
}
