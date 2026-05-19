//
//  AddServerView.swift
//  BarkMate
//
//  Phase 4-Core: 添加服务器表单 + 测试连通性 + 注册 device token。
//

import SwiftUI
import SwiftData
import Factory
import Models
import Store
import BarkService

struct AddServerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var address: String = "https://"
    @State private var testState: TestState = .idle
    @State private var saving: Bool = false

    @Injected(\.barkClient) private var barkClient: BarkClientProtocol
    @Injected(\.deviceTokenStore) private var tokenStore: DeviceTokenStore

    enum TestState: Equatable {
        case idle
        case testing
        case ok
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Display name (optional)", text: $name)
                        .autocorrectionDisabled()
                    TextField("https://api.example.com", text: $address)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            Text("Test connection")
                            Spacer()
                            testStateView
                        }
                    }
                    .disabled(!isAddressValid || testState == .testing)
                }

                Section {
                    Text("BarkMate will register the APNs token to this server on save. The server will return a key used to push messages to your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!isAddressValid || saving)
                }
            }
        }
    }

    @ViewBuilder
    private var testStateView: some View {
        switch testState {
        case .idle: EmptyView()
        case .testing: ProgressView().scaleEffect(0.7)
        case .ok:
            Label("OK", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .labelStyle(.iconOnly)
        case .failed(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    private var isAddressValid: Bool {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false
        else { return false }
        return true
    }

    private func testConnection() async {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespaces)) else { return }
        testState = .testing
        do {
            let ok = try await barkClient.ping(serverURL: url)
            testState = ok ? .ok : .failed("Server returned non-200")
        } catch let error as BarkAPIError {
            testState = .failed(describe(error))
        } catch {
            testState = .failed(error.localizedDescription)
        }
    }

    private func save() async {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespaces)) else { return }
        saving = true
        defer { saving = false }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let server = Server(
            name: trimmedName.isEmpty ? nil : trimmedName,
            address: url.absoluteString,
            key: "",
            state: .pending
        )

        if let token = tokenStore.token() {
            do {
                let key = try await barkClient.register(
                    deviceToken: token,
                    serverURL: url,
                    existingKey: nil
                )
                server.key = key
                server.state = .ok
                server.lastSyncedAt = .now
            } catch {
                server.state = .error
            }
        }

        modelContext.insert(server)
        try? modelContext.save()
        dismiss()
    }

    private func describe(_ error: BarkAPIError) -> String {
        switch error {
        case .invalidURL: return "Invalid URL"
        case .networkError: return "Network error"
        case .httpStatus(let code): return "HTTP \(code)"
        case .serverError(_, let msg): return msg ?? "Server error"
        case .decodingFailed: return "Bad response"
        }
    }
}
