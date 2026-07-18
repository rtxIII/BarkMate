//
//  ServerListView.swift
//  BarkAgent
//
//  Phase 4-Core: 服务器列表 + 状态点 + 添加 + 删除 + 健康检查刷新。
//

import SwiftUI
import SwiftData
import Factory
import Models
import BarkService

struct ServerListView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Server.createdAt, order: .reverse)
    private var servers: [Server]

    @State private var showingAdd: Bool = false
    @State private var refreshing: Set<UUID> = []

    @Injected(\.barkClient) private var barkClient: BarkClientProtocol

    var body: some View {
        Group {
            if servers.isEmpty {
                ContentUnavailableView(
                    "No servers",
                    systemImage: "server.rack",
                    description: Text("Add a Bark server to start receiving pushes.")
                )
            } else {
                List {
                    ForEach(servers) { server in
                        ServerRow(server: server, isRefreshing: refreshing.contains(server.id))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    delete(server)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("server-list-add")
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Task { await refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(servers.isEmpty)
                .accessibilityIdentifier("server-list-refresh")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddServerView()
        }
        .refreshable { await refreshAll() }
    }

    // MARK: - Actions

    private func delete(_ server: Server) {
        modelContext.delete(server)
        try? modelContext.save()
    }

    private func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for server in servers {
                group.addTask { await ping(server) }
            }
        }
    }

    private func ping(_ server: Server) async {
        guard let url = URL(string: server.address) else {
            await MainActor.run {
                server.state = .error
                try? modelContext.save()
            }
            return
        }
        await MainActor.run { _ = refreshing.insert(server.id) }
        defer { Task { @MainActor in refreshing.remove(server.id) } }

        do {
            let ok = try await barkClient.ping(serverURL: url)
            await MainActor.run {
                server.state = ok ? .ok : .error
                server.lastSyncedAt = .now
                try? modelContext.save()
            }
        } catch {
            await MainActor.run {
                server.state = .error
                try? modelContext.save()
            }
        }
    }
}

// MARK: - Row

private struct ServerRow: View {
    let server: Server
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 12) {
            stateIndicator
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name ?? server.address)
                    .font(.body)
                Text(server.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let last = server.lastSyncedAt {
                    Text("Last check: \(last, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if !server.key.isEmpty {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var stateIndicator: some View {
        if isRefreshing {
            ProgressView().scaleEffect(0.7)
        } else {
            Circle()
                .fill(stateColor)
                .frame(width: 10, height: 10)
        }
    }

    private var stateColor: Color {
        switch server.state {
        case .ok: return .green
        case .error: return .red
        case .pending: return .gray
        }
    }
}
