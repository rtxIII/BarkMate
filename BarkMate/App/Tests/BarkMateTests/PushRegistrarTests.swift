import XCTest
import SwiftData
@testable import BarkAgent
import BarkService
import Models
import Store

final class PushRegistrarTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var client: MockBarkClient!
    private var registrar: PushRegistrar!

    override func setUpWithError() throws {
        modelContainer = try SharedModelContainer.makeInMemory()
        suiteName = "PushRegistrarTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create UserDefaults suite")
        }
        self.defaults = defaults
        client = MockBarkClient()
        registrar = PushRegistrar(
            modelContainer: modelContainer,
            barkClient: client,
            tokenStore: DeviceTokenStore(defaults: defaults),
            statusStore: NotificationStatusStore(defaults: defaults)
        )
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        registrar = nil
        client = nil
        defaults = nil
        suiteName = nil
        modelContainer = nil
    }

    @MainActor
    func testSeedDefaultServerCreatesPendingCloudServerWhenEmpty() throws {
        registrar.seedDefaultServerIfNeeded()

        let servers = try modelContainer.mainContext.fetch(FetchDescriptor<Server>())
        XCTAssertEqual(servers.count, 1)
        XCTAssertEqual(servers.first?.name, PushRegistrar.defaultServerName)
        XCTAssertEqual(servers.first?.address, PushRegistrar.defaultServerAddress)
        XCTAssertEqual(servers.first?.key, "")
        XCTAssertEqual(servers.first?.state, .pending)
    }

    @MainActor
    func testSeedDefaultServerDoesNotDuplicateExistingServer() throws {
        let existing = Server(name: "Self hosted", address: "https://example.com", key: "key", state: .ok)
        modelContainer.mainContext.insert(existing)
        try modelContainer.mainContext.save()

        registrar.seedDefaultServerIfNeeded()

        let servers = try modelContainer.mainContext.fetch(FetchDescriptor<Server>())
        XCTAssertEqual(servers.count, 1)
        XCTAssertEqual(servers.first?.name, "Self hosted")
    }

    @MainActor
    func testHandleDeviceTokenRegistersServersAndMarksStatusOK() async throws {
        let first = Server(address: "https://one.example.com", key: "", state: .pending)
        let second = Server(address: "https://two.example.com", key: "existing-key", state: .pending)
        modelContainer.mainContext.insert(first)
        modelContainer.mainContext.insert(second)
        try modelContainer.mainContext.save()
        client.registerResults = [
            "https://one.example.com": .success("new-key"),
            "https://two.example.com": .success("kept-key")
        ]

        await registrar.handleDeviceToken("apns-token")

        XCTAssertEqual(DeviceTokenStore(defaults: defaults).token(), "apns-token")
        XCTAssertNil(client.registerCalls.first(where: { $0.serverURL.host == "one.example.com" })?.existingKey)
        XCTAssertEqual(
            client.registerCalls.first(where: { $0.serverURL.host == "two.example.com" })?.existingKey,
            "existing-key"
        )
        XCTAssertEqual(Set(client.registerCalls.map(\.deviceToken)), ["apns-token"])
        XCTAssertEqual(first.key, "new-key")
        XCTAssertEqual(first.state, .ok)
        XCTAssertNotNil(first.lastSyncedAt)
        XCTAssertEqual(second.key, "kept-key")
        XCTAssertEqual(second.state, .ok)
        XCTAssertEqual(NotificationStatusStore(defaults: defaults).current().kind, .ok)
    }

    @MainActor
    func testHandleDeviceTokenPreservesStorageUnavailableAfterSuccessfulRegistration() async throws {
        let server = Server(address: "https://one.example.com", key: "", state: .pending)
        modelContainer.mainContext.insert(server)
        try modelContainer.mainContext.save()
        client.registerResults = [
            "https://one.example.com": .success("new-key")
        ]
        NotificationStatusStore(defaults: defaults).save(NotificationStatus(
            kind: .storageUnavailable,
            detail: "Shared storage unavailable"
        ))

        await registrar.handleDeviceToken("apns-token")

        XCTAssertEqual(server.state, .ok)
        let status = NotificationStatusStore(defaults: defaults).current()
        XCTAssertEqual(status.kind, .storageUnavailable)
        XCTAssertEqual(status.detail, "Shared storage unavailable")
    }

    @MainActor
    func testHandleDeviceTokenMarksFailedServerAndStatusUnreachable() async throws {
        let good = Server(address: "https://good.example.com", key: "", state: .pending)
        let bad = Server(address: "https://bad.example.com", key: "", state: .pending)
        modelContainer.mainContext.insert(good)
        modelContainer.mainContext.insert(bad)
        try modelContainer.mainContext.save()
        client.registerResults = [
            "https://good.example.com": .success("good-key"),
            "https://bad.example.com": .failure(BarkAPIError.httpStatus(500))
        ]

        await registrar.handleDeviceToken("apns-token")

        XCTAssertEqual(good.state, .ok)
        XCTAssertEqual(good.key, "good-key")
        XCTAssertEqual(bad.state, .error)
        XCTAssertEqual(bad.key, "")
        let status = NotificationStatusStore(defaults: defaults).current()
        XCTAssertEqual(status.kind, .serverUnreachable)
        XCTAssertEqual(status.detail, "One or more servers failed to register. Open Servers to retry.")
    }

    @MainActor
    func testHandleDeviceTokenRejectsInvalidServerURLWithoutCallingClient() async throws {
        let server = Server(address: "", key: "", state: .pending)
        modelContainer.mainContext.insert(server)
        try modelContainer.mainContext.save()

        await registrar.handleDeviceToken("apns-token")

        XCTAssertTrue(client.registerCalls.isEmpty)
        XCTAssertEqual(server.state, .error)
        XCTAssertEqual(NotificationStatusStore(defaults: defaults).current().kind, .serverUnreachable)
    }
}

private final class MockBarkClient: BarkClientProtocol, @unchecked Sendable {
    struct RegisterCall: Equatable {
        let deviceToken: String
        let serverURL: URL
        let existingKey: String?
    }

    var registerResults: [String: Result<String, Error>] = [:]
    private(set) var registerCalls: [RegisterCall] = []

    func register(deviceToken: String, serverURL: URL, existingKey: String?) async throws -> String {
        registerCalls.append(RegisterCall(
            deviceToken: deviceToken,
            serverURL: serverURL,
            existingKey: existingKey
        ))
        let key = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch registerResults[key] {
        case .success(let assignedKey):
            return assignedKey
        case .failure(let error):
            throw error
        case nil:
            return "registered-key"
        }
    }

    func ping(serverURL: URL) async throws -> Bool {
        true
    }
}
