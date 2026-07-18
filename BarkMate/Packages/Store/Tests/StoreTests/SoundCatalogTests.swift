import XCTest
@testable import Store

final class SoundCatalogTests: XCTestCase {

    func testBarkSoundsCountAndSilencePresent() {
        XCTAssertEqual(SoundCatalog.barkSounds.count, 32)
        XCTAssertTrue(SoundCatalog.barkSounds.contains { $0.id == "silence" })
    }

    func testAllIncludesSystemDefaultFirst() {
        XCTAssertEqual(SoundCatalog.all.first?.id, SoundCatalog.systemDefaultID)
        XCTAssertEqual(SoundCatalog.all.count, SoundCatalog.barkSounds.count + 1)
    }

    func testIDsAreUnique() {
        let ids = SoundCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testFileNameMapping() {
        XCTAssertEqual(SoundCatalog.sound(for: "bell")?.fileName, "bell.caf")
        XCTAssertEqual(SoundCatalog.sound(for: "silence")?.fileName, "silence.caf")
    }

    func testSystemDefaultHasEmptyFileName() {
        XCTAssertEqual(SoundCatalog.sound(for: SoundCatalog.systemDefaultID)?.fileName, "")
    }

    func testUnknownIDReturnsNil() {
        XCTAssertNil(SoundCatalog.sound(for: "does-not-exist"))
    }

    func testDisplayNameIsCapitalized() {
        XCTAssertEqual(SoundCatalog.sound(for: "bell")?.displayName, "Bell")
    }
}
