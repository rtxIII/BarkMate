import XCTest
@testable import BarkService
import Models

final class PushParserTests: XCTestCase {

    func testParsesStandardAlertPush() {
        let eta = "2026-05-19T10:30:00Z"
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "T",
                    "subtitle": "S",
                    "body": "Hello"
                ]
            ],
            "id": "msg-1",
            "url": "https://example.com",
            "image": "https://img.example.com/a.png",
            "icon": "https://img.example.com/icon.png",
            "group": "work",
            "agent_status": "running",
            "task_id": "task-1",
            "progress": "3/7",
            "eta": eta
        ]

        let parsed = PushParser.parse(userInfo: userInfo)

        XCTAssertEqual(parsed.id, "msg-1")
        XCTAssertEqual(parsed.title, "T")
        XCTAssertEqual(parsed.subtitle, "S")
        XCTAssertEqual(parsed.body, "Hello")
        XCTAssertEqual(parsed.bodyType, .plainText)
        XCTAssertEqual(parsed.group, "work")
        XCTAssertEqual(parsed.url, "https://example.com")
        XCTAssertEqual(parsed.imageURL, "https://img.example.com/a.png")
        XCTAssertEqual(parsed.iconURL, "https://img.example.com/icon.png")
        XCTAssertEqual(parsed.agentStatus, .running)
        XCTAssertEqual(parsed.taskID, "task-1")
        XCTAssertEqual(parsed.progress, "3/7")
        XCTAssertNotNil(parsed.eta)
        XCTAssertEqual(parsed.agentID, "work")
    }

    func testMarkdownOverridesBody() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": ["body": "plain"]],
            "markdown": "**bold**"
        ]
        let parsed = PushParser.parse(userInfo: userInfo)
        XCTAssertEqual(parsed.body, "**bold**")
        XCTAssertEqual(parsed.bodyType, .markdown)
    }

    func testCaseInsensitiveKeys() {
        let userInfo: [AnyHashable: Any] = [
            "APS": [
                "ALERT": ["TITLE": "Hi", "BODY": "world"]
            ],
            "GROUP": "uppercase-group",
            "AGENT_STATUS": "waiting_input"
        ]
        let parsed = PushParser.parse(userInfo: userInfo)
        XCTAssertEqual(parsed.title, "Hi")
        XCTAssertEqual(parsed.body, "world")
        XCTAssertEqual(parsed.group, "uppercase-group")
        XCTAssertEqual(parsed.agentStatus, .waitingInput)
    }

    func testAgentIDDefaultsWhenGroupMissing() {
        let parsed = PushParser.parse(userInfo: [
            "aps": ["alert": ["body": "x"]],
            "agent_status": "running"
        ])
        XCTAssertEqual(parsed.agentID, "default")
    }

    func testAgentIDPrefersExplicitAgentID() {
        // agent_id 存在时优先于 group,让多 console(同 group)可按 agent_id 分卡。
        let parsed = PushParser.parse(userInfo: [
            "aps": ["alert": ["body": "x"]],
            "agent_status": "running",
            "agent_id": "claude:projA",
            "group": "claude"
        ])
        XCTAssertEqual(parsed.agentID, "claude:projA")
        XCTAssertEqual(parsed.group, "claude")
    }

    func testAgentIDFallsBackToGroupWhenAgentIDMissing() {
        let parsed = PushParser.parse(userInfo: [
            "aps": ["alert": ["body": "x"]],
            "agent_status": "running",
            "group": "work"
        ])
        XCTAssertEqual(parsed.agentID, "work")
    }

    func testAgentIDFallsBackToDefaultWhenBothMissing() {
        let parsed = PushParser.parse(userInfo: [
            "aps": ["alert": ["body": "x"]],
            "agent_status": "running"
        ])
        XCTAssertEqual(parsed.agentID, "default")
    }

    func testGeneratesStableIdWhenMissing() {
        // C2: id 缺失时,parser 用 payload 内容稳定哈希 → 同 payload 两次解析 id 相同。
        let userInfo: [AnyHashable: Any] = ["aps": ["alert": ["body": "x"]]]
        let a = PushParser.parse(userInfo: userInfo)
        let b = PushParser.parse(userInfo: userInfo)
        XCTAssertFalse(a.id.isEmpty)
        XCTAssertEqual(a.id, b.id, "same payload should yield identical fallback id")
    }

    func testDifferentPayloadsGetDifferentFallbackIds() {
        let a = PushParser.parse(userInfo: ["aps": ["alert": ["body": "x"]]])
        let b = PushParser.parse(userInfo: ["aps": ["alert": ["body": "y"]]])
        XCTAssertNotEqual(a.id, b.id)
    }

    func testExplicitIdOverridesFallback() {
        let parsed = PushParser.parse(userInfo: [
            "aps": ["alert": ["body": "x"]],
            "id": "explicit-msg-1"
        ])
        XCTAssertEqual(parsed.id, "explicit-msg-1")
    }

    func testCiphertextPreservedForDecryptProcessor() {
        let parsed = PushParser.parse(userInfo: [
            "ciphertext": "enc-data-base64",
            "iv": "should-be-ignored-by-parser"
        ])
        XCTAssertEqual(parsed.ciphertext, "enc-data-base64")
        XCTAssertEqual(parsed.body, "") // no alert → empty body
    }

    func testEmptyBodyStaysEmpty() {
        let parsed = PushParser.parse(userInfo: [:])
        XCTAssertEqual(parsed.body, "")
        XCTAssertEqual(parsed.tags, [])
    }

    // MARK: - Codable backward-compat (PendingQueue on-disk data)

    func testDecodesLegacyJSONWithoutAgentIDOverride() throws {
        // 旧 PendingQueue 文件不含 agentIDOverride 键;新模型必须容忍缺失(解为 nil),
        // agentID 退回 group,保持旧行为。防止未来加 CodingKeys 破坏离线队列兼容。
        let legacy = #"{"id":"m1","body":"hi","bodyType":"plainText","tags":[],"group":"work","createdAt":768000000}"#
        let data = Data(legacy.utf8)
        let parsed = try JSONDecoder().decode(ParsedPush.self, from: data)
        XCTAssertNil(parsed.agentIDOverride)
        XCTAssertEqual(parsed.agentID, "work")
    }

    func testParsedPushRoundTripsThroughCodable() throws {
        let original = PushParser.parse(userInfo: [
            "aps": ["alert": ["body": "x"]],
            "agent_status": "running",
            "agent_id": "claude:projA",
            "group": "claude",
            "task_id": "sess-1"
        ])
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(ParsedPush.self, from: data)
        XCTAssertEqual(restored.agentIDOverride, "claude:projA")
        XCTAssertEqual(restored.agentID, "claude:projA")
    }

    // MARK: - Tag extraction

    func testExtractEnglishTags() {
        let tags = PushParser.extractTags(from: "Pushed from #work and #urgent-task")
        XCTAssertEqual(tags, ["work", "urgent-task"])
    }

    func testExtractChineseTags() {
        let tags = PushParser.extractTags(from: "今天 #工作 遇到个 #bug 要处理 #工作 (dup)")
        XCTAssertEqual(tags, ["工作", "bug"])
    }

    func testNoTags() {
        XCTAssertEqual(PushParser.extractTags(from: "plain text"), [])
        XCTAssertEqual(PushParser.extractTags(from: ""), [])
        XCTAssertEqual(PushParser.extractTags(from: "# just a hash"), [])
    }

    func testTagsInBodyPopulateParsed() {
        let parsed = PushParser.parse(userInfo: [
            "aps": ["alert": ["body": "deploy done #ops #v1.2"]]
        ])
        XCTAssertEqual(parsed.tags, ["ops", "v1"])
    }
}
