//
//  KeychainServiceTests.swift
//  StoreTests
//
//  仅验证 add/get/delete 逻辑。access-group 共享需在真机/模拟器验证。
//

import XCTest
@testable import Store

final class KeychainServiceTests: XCTestCase {

    private let config = KeychainService.Configuration(
        accessGroup: nil,
        service: "com.barkmate.tests.\(UUID().uuidString)"
    )

    override func tearDownWithError() throws {
        try? KeychainService.delete(forKey: "test.key", configuration: config)
    }

    func testSetAndGet() throws {
        let payload = Data("secret".utf8)
        try KeychainService.set(payload, forKey: "test.key", configuration: config)

        let fetched = try KeychainService.get(forKey: "test.key", configuration: config)
        XCTAssertEqual(fetched, payload)
    }

    func testOverwriteExisting() throws {
        try KeychainService.set(Data("v1".utf8), forKey: "test.key", configuration: config)
        try KeychainService.set(Data("v2".utf8), forKey: "test.key", configuration: config)

        let fetched = try KeychainService.get(forKey: "test.key", configuration: config)
        XCTAssertEqual(fetched, Data("v2".utf8))
    }

    func testDelete() throws {
        try KeychainService.set(Data("bye".utf8), forKey: "test.key", configuration: config)
        try KeychainService.delete(forKey: "test.key", configuration: config)

        let fetched = try KeychainService.get(forKey: "test.key", configuration: config)
        XCTAssertNil(fetched)
    }

    func testGetMissingReturnsNil() throws {
        let fetched = try KeychainService.get(forKey: "nonexistent.key", configuration: config)
        XCTAssertNil(fetched)
    }

    func testDeleteMissingIsNoOp() throws {
        XCTAssertNoThrow(try KeychainService.delete(forKey: "nonexistent.key", configuration: config))
    }

    func testSharedConfigurationMatchesDeclaredKeychainAccessGroup() {
        let sharedConfiguration = KeychainService.Configuration.shared(teamID: "TESTTEAM")

        XCTAssertEqual(sharedConfiguration.accessGroup, "TESTTEAM.com.barkagent.shared")
    }
}
