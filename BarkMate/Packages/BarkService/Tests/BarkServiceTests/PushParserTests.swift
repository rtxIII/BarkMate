import XCTest
@testable import BarkService
import Models

final class PushParserTests: XCTestCase {

    func testParsesStandardAlertPush() {
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
            "group": "work"
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
            "GROUP": "uppercase-group"
        ]
        let parsed = PushParser.parse(userInfo: userInfo)
        XCTAssertEqual(parsed.title, "Hi")
        XCTAssertEqual(parsed.body, "world")
        XCTAssertEqual(parsed.group, "uppercase-group")
    }

    func testGeneratesIdWhenMissing() {
        let parsed = PushParser.parse(userInfo: ["aps": ["alert": ["body": "x"]]])
        XCTAssertFalse(parsed.id.isEmpty)
        XCTAssertNotEqual(parsed.id, "msg-1")
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
