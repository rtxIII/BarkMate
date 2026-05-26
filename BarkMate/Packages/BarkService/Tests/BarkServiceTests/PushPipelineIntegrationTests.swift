import XCTest
import SwiftData
import CryptoSwift
@testable import BarkService
import Models
import Store

/// PushPipeline 的集成测试 — 端到端 simulate NSE 收到的 APNs userInfo:
/// 验证 decrypt → parse → archive 在 NSE-shape 输入下与单元测试结论一致。
/// 等价于 NotificationService.didReceive 的内部 pipeline,只是不依赖
/// UserNotifications.framework(simctl push 在 simulator 不会触发 NSE)。
final class PushPipelineIntegrationTests: XCTestCase {

    private var storeURL: URL!
    private var container: ModelContainer!
    private var pendingDir: URL!

    override func setUpWithError() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appending(path: "PushPipelineTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        storeURL = tmpDir.appending(path: "store.sqlite")
        container = try SharedModelContainer.make(storeURL: storeURL)
        pendingDir = tmpDir.appending(path: "pending", directoryHint: .isDirectory)
    }

    override func tearDownWithError() throws {
        if let storeURL {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }
        container = nil
        pendingDir = nil
    }

    // MARK: - Agent path

    @MainActor
    func testV03AgentPushArchivesTaskAndStep() throws {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Build pipeline",
                    "body": "Step 3 of 7: lint passed"
                ],
                "mutable-content": 1,
                "sound": "default"
            ],
            "id": "e2e-running-001",
            "group": "ci-bot",
            "task_id": "build-42",
            "agent_status": "running",
            "progress": "3/7"
        ]

        let outcome = PushPipeline.process(
            userInfo: userInfo,
            bundle: nil,
            container: container,
            queue: PendingQueue(baseDirectory: pendingDir)
        )

        guard case .archived(let parsed, let decrypt, let kind) = outcome else {
            return XCTFail("expected archived, got \(outcome)")
        }
        XCTAssertEqual(kind, .agent)
        XCTAssertFalse(decrypt.decryptionFailed)
        XCTAssertEqual(parsed.id, "e2e-running-001")
        XCTAssertEqual(parsed.agentStatus, .running)
        XCTAssertEqual(parsed.progress, "3/7")
        XCTAssertEqual(parsed.taskID, "build-42")

        let tasks = try container.mainContext.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.aggregateKey, "ci-bot::build-42")
        XCTAssertEqual(tasks.first?.status, .running)
        XCTAssertEqual(tasks.first?.progress, "3/7")
        XCTAssertEqual(tasks.first?.latestStepTitle, "Build pipeline")

        let steps = try container.mainContext.fetch(FetchDescriptor<AgentStep>())
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps.first?.body, "Step 3 of 7: lint passed")
        XCTAssertEqual(steps.first?.progress, "3/7")
    }

    @MainActor
    func testMultipleV03PushesAggregateAndAdvanceStatus() throws {
        let queue = PendingQueue(baseDirectory: pendingDir)
        let pushes: [[AnyHashable: Any]] = [
            v03Payload(id: "p-1", title: "lint", body: "Step 3 of 7", status: "running", progress: "3/7"),
            v03Payload(id: "p-2", title: "tests", body: "Step 5 of 7", status: "running", progress: "5/7"),
            v03Payload(id: "p-3", title: "complete", body: "All 7 steps passed", status: "done", progress: "7/7")
        ]

        for userInfo in pushes {
            let outcome = PushPipeline.process(
                userInfo: userInfo,
                bundle: nil,
                container: container,
                queue: queue
            )
            guard case .archived = outcome else {
                return XCTFail("expected archived, got \(outcome)")
            }
        }

        let tasks = try container.mainContext.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(tasks.count, 1, "same agent_id+task_id collapse to single task")
        XCTAssertEqual(tasks.first?.status, .done)
        XCTAssertEqual(tasks.first?.progress, "7/7")
        XCTAssertEqual(tasks.first?.latestStepTitle, "complete")

        let steps = try container.mainContext.fetch(FetchDescriptor<AgentStep>())
        XCTAssertEqual(steps.count, 3, "every push appends a step")
    }

    // MARK: - Memo path (legacy)

    @MainActor
    func testLegacyPushWithoutAgentStatusBecomesIncomingMemo() throws {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Old Bark",
                    "body": "Hello from legacy client"
                ]
            ],
            "id": "e2e-legacy-001",
            "group": "general"
        ]

        let outcome = PushPipeline.process(
            userInfo: userInfo,
            bundle: nil,
            container: container,
            queue: PendingQueue(baseDirectory: pendingDir)
        )

        guard case .archived(_, _, let kind) = outcome else {
            return XCTFail("expected archived, got \(outcome)")
        }
        XCTAssertEqual(kind, .memo(.incoming))

        let tasks = try container.mainContext.fetch(FetchDescriptor<AgentTask>())
        XCTAssertTrue(tasks.isEmpty, "legacy push must not create AgentTask")
        let memos = try container.mainContext.fetch(FetchDescriptor<Memo>())
        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos.first?.source, .incoming)
        XCTAssertEqual(memos.first?.title, "Old Bark")
        XCTAssertEqual(memos.first?.body, "Hello from legacy client")
    }

    // MARK: - Pending queue degrade

    @MainActor
    func testNilContainerEnqueuesIntoPendingQueue() throws {
        let queue = PendingQueue(baseDirectory: pendingDir)
        let userInfo = v03Payload(id: "p-pending", title: "x", body: "y", status: "running", progress: "1/3")

        let outcome = PushPipeline.process(
            userInfo: userInfo,
            bundle: nil,
            container: nil,
            queue: queue
        )
        guard case .pending(let parsed, _) = outcome else {
            return XCTFail("expected pending, got \(outcome)")
        }
        XCTAssertEqual(parsed.id, "p-pending")
        XCTAssertEqual(try queue.count(), 1)

        // 主 App 起来后调 drain → 重新走 PushArchiver,task/step 进库。
        let drained = try queue.drain()
        XCTAssertEqual(drained.count, 1)
        let archiver = PushArchiver(modelContainer: container)
        try archiver.archive(drained[0])
        let tasks = try container.mainContext.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(tasks.count, 1)
    }

    // MARK: - Decryption failure degrade

    @MainActor
    func testEncryptedPushWithoutBundleArchivesCipherDegraded() throws {
        let userInfo: [AnyHashable: Any] = [
            "aps": [:],
            "id": "e2e-encrypted-001",
            "ciphertext": "AAECAwQFBgcICQoLDA0ODw==",
            "iv": "1234567890abcdef"
        ]

        let outcome = PushPipeline.process(
            userInfo: userInfo,
            bundle: nil,
            container: container,
            queue: PendingQueue(baseDirectory: pendingDir)
        )

        guard case .archived(_, let decrypt, let kind) = outcome else {
            return XCTFail("expected archived, got \(outcome)")
        }
        XCTAssertTrue(decrypt.decryptionFailed)
        XCTAssertEqual(decrypt.originalCiphertext, "AAECAwQFBgcICQoLDA0ODw==")
        XCTAssertEqual(decrypt.originalIV, "1234567890abcdef")
        XCTAssertEqual(kind, .memo(.incoming))

        let memos = try container.mainContext.fetch(FetchDescriptor<Memo>())
        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos.first?.body, "Decryption Failed")
        XCTAssertNotNil(memos.first?.metadata, "ciphertext stashed for later recovery")
    }

    // MARK: - Encrypted v0.3 success (Task C 替代验证)

    @MainActor
    func testEncryptedV03AgentPushDecryptsAndArchivesAsAgent() throws {
        let key = Data("0123456789abcdef0123456789abcdef".utf8) // AES-256
        let iv = Data("abcdef0123456789".utf8)                  // 16B
        let bundle = CryptoBundle(
            algorithm: .aes256,
            mode: .cbc,
            padding: .pkcs7,
            key: key,
            iv: iv
        )

        // 服务端会把 v0.3 字段(明文 alert + agent_status + task_id + progress + group)
        // 整个 JSON 加密成单一 ciphertext;DecryptProcessor 解密后小写键合并,
        // title/body 重建到 aps.alert,其它字段平铺到 userInfo 顶层。
        let plain: [String: Any] = [
            "title": "Build pipeline",
            "body": "Step 3 of 7: lint passed",
            "group": "ci-bot",
            "task_id": "build-42",
            "agent_status": "running",
            "progress": "3/7",
            "id": "e2e-encrypted-running-001"
        ]
        let ciphertext = try encrypt(plain, using: bundle)
        let userInfo: [AnyHashable: Any] = ["ciphertext": ciphertext]

        let outcome = PushPipeline.process(
            userInfo: userInfo,
            bundle: bundle,
            container: container,
            queue: PendingQueue(baseDirectory: pendingDir)
        )

        guard case .archived(let parsed, let decrypt, let kind) = outcome else {
            return XCTFail("expected archived agent, got \(outcome)")
        }
        XCTAssertFalse(decrypt.decryptionFailed)
        XCTAssertEqual(kind, .agent)
        XCTAssertEqual(parsed.id, "e2e-encrypted-running-001")
        XCTAssertEqual(parsed.title, "Build pipeline")
        XCTAssertEqual(parsed.agentStatus, .running)
        XCTAssertEqual(parsed.taskID, "build-42")
        XCTAssertEqual(parsed.progress, "3/7")

        let tasks = try container.mainContext.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.aggregateKey, "ci-bot::build-42")
        XCTAssertEqual(tasks.first?.status, .running)

        let steps = try container.mainContext.fetch(FetchDescriptor<AgentStep>())
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps.first?.body, "Step 3 of 7: lint passed")
        XCTAssertEqual(steps.first?.progress, "3/7")
    }

    private func encrypt(_ plain: [String: Any], using bundle: CryptoBundle) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: plain)
        let plainText = String(data: data, encoding: String.Encoding.utf8) ?? ""
        let aes = try AES(
            key: [UInt8](bundle.key),
            blockMode: CBC(iv: [UInt8](bundle.iv)),
            padding: .pkcs7
        )
        let cipherBytes = try aes.encrypt(Array(plainText.utf8))
        return Data(cipherBytes).base64EncodedString()
    }

    // MARK: - Helpers

    private func v03Payload(
        id: String,
        title: String,
        body: String,
        status: String,
        progress: String
    ) -> [AnyHashable: Any] {
        [
            "aps": [
                "alert": ["title": title, "body": body],
                "mutable-content": 1
            ],
            "id": id,
            "group": "ci-bot",
            "task_id": "build-42",
            "agent_status": status,
            "progress": progress
        ]
    }
}
