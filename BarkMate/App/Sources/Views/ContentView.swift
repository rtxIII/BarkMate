//
//  ContentView.swift
//  BarkAgent
//

import SwiftUI
import SwiftData
import Models

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        MainTabView()
            .task { seedUITestDataIfNeeded() }
    }

    private func seedUITestDataIfNeeded() {
        let env = ProcessInfo.processInfo.environment
        guard env["BARKAGENT_UI_TESTING"] == "1" else { return }

        var descriptor = FetchDescriptor<AgentTask>()
        descriptor.fetchLimit = 1
        guard (try? modelContext.fetch(descriptor))?.isEmpty != false else { return }

        switch env["BARKAGENT_UI_SEED_SCENARIO"] {
        case "agent-detail":
            seedAgentDetailScenario()
        case "dashboard-dense":
            seedDenseDashboardScenario()
        case "search-history":
            seedSearchHistoryScenario()
        case "server-health":
            seedServerHealthScenario()
        case "settings-statuses":
            seedSettingsStatusesScenario()
        case "showcase":
            seedShowcaseScenario()
        default:
            return
        }
    }

    private func seedAgentDetailScenario() {
        let now = Date()
        let task = AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: "codex-coverage", taskID: "COV-42"),
            agentID: "codex-coverage",
            taskID: "COV-42",
            displayName: "Codex Coverage Probe",
            status: .blocked,
            latestStepTitle: "Need review",
            progress: "65%",
            eta: now.addingTimeInterval(900),
            lastSummary: "Coverage seed summary is ready.",
            lastSummaryAt: now.addingTimeInterval(-60),
            createdAt: now.addingTimeInterval(-600),
            updatedAt: now.addingTimeInterval(-30)
        )
        let firstStep = AgentStep(
            task: task,
            status: .running,
            title: "Boot runner",
            body: "Started the seeded UI coverage task.",
            progress: "25%",
            createdAt: now.addingTimeInterval(-500)
        )
        let secondStep = AgentStep(
            task: task,
            status: .blocked,
            title: "Need review",
            body: "Waiting for an operator to inspect the generated test path.",
            progress: "65%",
            createdAt: now.addingTimeInterval(-120)
        )
        task.steps = [firstStep, secondStep]

        modelContext.insert(task)
        modelContext.insert(Server(
            name: "Seed Bark Server",
            address: "https://seed.barkagent.test",
            key: "seed-key",
            state: .ok,
            lastSyncedAt: now.addingTimeInterval(-180)
        ))
        try? modelContext.save()
    }

    private func seedDenseDashboardScenario() {
        let now = Date()
        let fixtures: [(agentID: String, displayName: String, status: AgentStatus, step: String, progress: String)] = [
            ("dense-wait", "Dense Wait Probe", .waitingInput, "Waiting for operator input", "1/4"),
            ("dense-block", "Dense Block Probe", .blocked, "Blocked on access token", "2/5"),
            ("dense-run-alpha", "Dense Run Alpha", .running, "Compiling release assets", "25%"),
            ("dense-run-beta", "Dense Run Beta", .running, "Running integration tests", "50%"),
            ("dense-run-gamma", "Dense Run Gamma", .running, "Deploying canary", "75%"),
            ("dense-done", "Dense Done Probe", .done, "Release completed", "100%"),
            ("dense-fail", "Dense Fail Probe", .failed, "Deployment failed", "3/5")
        ]

        for (index, fixture) in fixtures.enumerated() {
            modelContext.insert(AgentTask(
                aggregateKey: AgentTask.aggregateKey(agentID: fixture.agentID, taskID: fixture.agentID.uppercased()),
                agentID: fixture.agentID,
                taskID: fixture.agentID.uppercased(),
                displayName: fixture.displayName,
                status: fixture.status,
                latestStepTitle: fixture.step,
                progress: fixture.progress,
                createdAt: now.addingTimeInterval(TimeInterval(-600 - index)),
                updatedAt: now.addingTimeInterval(TimeInterval(-index))
            ))
        }
        try? modelContext.save()
    }

    private func seedSearchHistoryScenario() {
        let now = Date()
        let staleTask = AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: "history-stale", taskID: "STALE-7"),
            agentID: "history-stale",
            taskID: "STALE-7",
            displayName: "History Stale Probe",
            status: .stale,
            latestStepTitle: "Waiting too long",
            progress: "40%",
            createdAt: now.addingTimeInterval(-9_000),
            updatedAt: now.addingTimeInterval(-7_200)
        )
        staleTask.steps = [
            AgentStep(
                task: staleTask,
                status: .stale,
                title: "Stale checkpoint",
                body: "Coverage stale agent needs operator attention.",
                progress: "40%",
                createdAt: now.addingTimeInterval(-7_200)
            )
        ]

        let doneTask = AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: "history-done", taskID: "DONE-9"),
            agentID: "history-done",
            taskID: "DONE-9",
            displayName: "History Done Probe",
            status: .done,
            latestStepTitle: "Release handoff",
            progress: "100%",
            createdAt: now.addingTimeInterval(-4_000),
            updatedAt: now.addingTimeInterval(-600)
        )
        doneTask.steps = [
            AgentStep(
                task: doneTask,
                status: .done,
                title: "Release handoff",
                body: "Coverage release handoff completed for search results.",
                progress: "100%",
                createdAt: now.addingTimeInterval(-600)
            )
        ]

        let failedTask = AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: "search-failure", taskID: "FAIL-3"),
            agentID: "search-failure",
            taskID: "FAIL-3",
            displayName: "Search Failure Probe",
            status: .failed,
            latestStepTitle: "Build failed",
            progress: "80%",
            createdAt: now.addingTimeInterval(-3_000),
            updatedAt: now.addingTimeInterval(-300)
        )

        modelContext.insert(staleTask)
        modelContext.insert(doneTask)
        modelContext.insert(failedTask)
        modelContext.insert(AgentInboxItem(
            title: "Incoming Alert Probe",
            body: "Coverage incoming bark payload for history and search.",
            group: "coverage",
            createdAt: now.addingTimeInterval(-120),
            updatedAt: now.addingTimeInterval(-120)
        ))
        try? modelContext.save()
    }

    private func seedServerHealthScenario() {
        modelContext.insert(Server(
            name: "Refresh Probe",
            address: "https://refresh.barkagent.test",
            key: "refresh-key",
            state: .pending,
            createdAt: Date().addingTimeInterval(-60)
        ))
        try? modelContext.save()
    }

    private func seedSettingsStatusesScenario() {
        let now = Date()
        modelContext.insert(Server(
            name: "Online Settings Probe",
            address: "https://online.barkagent.test",
            key: "online-key",
            state: .ok,
            lastSyncedAt: now.addingTimeInterval(-60),
            createdAt: now.addingTimeInterval(-180)
        ))
        modelContext.insert(Server(
            name: "Offline Settings Probe",
            address: "https://offline.barkagent.test",
            key: "",
            state: .error,
            createdAt: now.addingTimeInterval(-120)
        ))
        modelContext.insert(Server(
            name: "Pending Settings Probe",
            address: "https://pending.barkagent.test",
            key: "pending-key",
            state: .pending,
            createdAt: now.addingTimeInterval(-60)
        ))
        try? modelContext.save()
    }

    /// App Store 商店截图专用 seed。真实感 agent 名 + 全状态桶(needs-you / running /
    /// settled)。主角 `backend-refactor` 带 3 步历史，供详情页截图。
    private func seedShowcaseScenario() {
        let now = Date()

        // 详情页主角：running，带完整 step 历史。
        let hero = AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: "backend-refactor", taskID: "auth-migration"),
            agentID: "backend-refactor",
            taskID: "auth-migration",
            displayName: "backend-refactor",
            status: .running,
            latestStepTitle: "Refactoring auth middleware",
            progress: "3/5",
            eta: now.addingTimeInterval(720),
            createdAt: now.addingTimeInterval(-1_800),
            updatedAt: now.addingTimeInterval(-20)
        )
        hero.steps = [
            AgentStep(
                task: hero,
                status: .running,
                title: "Scan call sites",
                body: "Found 42 references to the legacy session token API.",
                progress: "1/5",
                createdAt: now.addingTimeInterval(-1_500)
            ),
            AgentStep(
                task: hero,
                status: .running,
                title: "Rewrite token store",
                body: "Migrated Keychain access group and rotated the signing key.",
                progress: "2/5",
                createdAt: now.addingTimeInterval(-720)
            ),
            AgentStep(
                task: hero,
                status: .running,
                title: "Refactoring auth middleware",
                body: "Swapping the request interceptor to the new async pipeline.",
                progress: "3/5",
                createdAt: now.addingTimeInterval(-20)
            )
        ]
        modelContext.insert(hero)

        // 其余卡片：覆盖 needs-you / running / settled 三桶。
        let cards: [(agentID: String, name: String, status: AgentStatus, step: String, progress: String, ago: TimeInterval)] = [
            ("test-writer", "test-writer", .waitingInput, "Confirm overwrite existing mocks", "4/7", -90),
            ("log-analyzer", "log-analyzer", .blocked, "Missing Grafana token — add it or skip", "2/5", -300),
            ("e2e-runner", "e2e-runner", .running, "Running checkout-flow suite", "58%", -12),
            ("dependency-updater", "dependency-updater", .running, "Installing weekly bumps", "25%", -8),
            ("release-bot", "release-bot", .done, "Shipped v2.4.0 to production", "100%", -900),
            ("nightly-build", "nightly-build", .failed, "Archive step failed on signing", "80%", -1_200)
        ]
        for (index, card) in cards.enumerated() {
            modelContext.insert(AgentTask(
                aggregateKey: AgentTask.aggregateKey(agentID: card.agentID, taskID: card.agentID.uppercased()),
                agentID: card.agentID,
                taskID: card.agentID.uppercased(),
                displayName: card.name,
                status: card.status,
                latestStepTitle: card.step,
                progress: card.progress,
                createdAt: now.addingTimeInterval(-1_800 - TimeInterval(index)),
                updatedAt: now.addingTimeInterval(card.ago)
            ))
        }

        modelContext.insert(Server(
            name: "BarkAgent Cloud",
            address: "https://barkagent.we2.xyz",
            key: "showcase-key",
            state: .ok,
            lastSyncedAt: now.addingTimeInterval(-45),
            createdAt: now.addingTimeInterval(-3_600)
        ))
        modelContext.insert(AgentInboxItem(
            title: "deploy-webhook",
            body: "Staging deploy finished in 3m12s.",
            group: "incoming",
            createdAt: now.addingTimeInterval(-200),
            updatedAt: now.addingTimeInterval(-200)
        ))
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
}
