import XCTest
@testable import BarkService
import Models

final class SearchEngineTests: XCTestCase {

    private var items: [Item]!

    override func setUp() {
        super.setUp()
        items = [
            Item(type: .push, title: "Deploy v1", body: "Production release", tags: ["ops", "deploy"], group: "ci",
                 createdAt: Date(timeIntervalSince1970: 1_700_000_000)),
            Item(type: .push, title: "Alert", body: "CPU 高 #urgent", tags: ["urgent"], group: "monitoring",
                 createdAt: Date(timeIntervalSince1970: 1_700_001_000)),
            Item(type: .memo, title: "Meeting notes", body: "**Discuss** roadmap", tags: ["work"], group: nil,
                 createdAt: Date(timeIntervalSince1970: 1_700_002_000)),
            Item(type: .memo, title: nil, body: "TODO refactor auth", tags: ["work", "refactor"], group: nil,
                 createdAt: Date(timeIntervalSince1970: 1_700_003_000))
        ]
    }

    func testEmptyQueryReturnsAll() {
        let result = SearchEngine.filter(items, query: SearchQuery())
        XCTAssertEqual(result.count, 4)
    }

    func testTextSearchTitle() {
        let result = SearchEngine.filter(items, query: SearchQuery(text: "Deploy"))
        XCTAssertEqual(result.map(\.title), ["Deploy v1"])
    }

    func testTextSearchBody() {
        let result = SearchEngine.filter(items, query: SearchQuery(text: "roadmap"))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.body, "**Discuss** roadmap")
    }

    func testTextSearchCaseInsensitive() {
        let result = SearchEngine.filter(items, query: SearchQuery(text: "RELEASE"))
        XCTAssertEqual(result.count, 1)
    }

    func testTypeFilter() {
        let result = SearchEngine.filter(items, query: SearchQuery(types: [.memo]))
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.type == .memo })
    }

    func testTagFilterMatchesAny() {
        let result = SearchEngine.filter(items, query: SearchQuery(tags: ["work"]))
        XCTAssertEqual(result.count, 2)
    }

    func testGroupFilter() {
        let result = SearchEngine.filter(items, query: SearchQuery(groups: ["ci"]))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Deploy v1")
    }

    func testDateRangeFilter() {
        let from = Date(timeIntervalSince1970: 1_700_001_500)
        let to = Date(timeIntervalSince1970: 1_700_002_500)
        let result = SearchEngine.filter(items, query: SearchQuery(dateRange: from...to))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Meeting notes")
    }

    func testCombinedFilters() {
        let query = SearchQuery(text: "TODO", types: [.memo], tags: ["work"])
        let result = SearchEngine.filter(items, query: query)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.body, "TODO refactor auth")
    }

    func testAvailableFacets() {
        let facets = SearchEngine.availableFacets(items)
        XCTAssertEqual(Set(facets.tags), ["ops", "deploy", "urgent", "work", "refactor"])
        XCTAssertEqual(Set(facets.groups), ["ci", "monitoring"])
    }

    func testChineseSearch() {
        let result = SearchEngine.filter(items, query: SearchQuery(text: "高"))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.body, "CPU 高 #urgent")
    }
}
