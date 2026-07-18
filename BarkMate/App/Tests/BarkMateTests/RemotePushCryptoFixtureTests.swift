import XCTest
import SwiftData
@testable import BarkAgent
import BarkService
import Models
import Store

@MainActor
final class RemotePushCryptoFixtureTests: XCTestCase {

    private let keyReference = "barkagent.remote-push-e2e.key"
    private let ivReference = "barkagent.remote-push-e2e.iv"
    private let encryptionKey = Data("0123456789abcdef0123456789abcdef".utf8)
    private let initializationVector = Data("abcdef0123456789".utf8)

    func testInstallSharedCryptoFixture() throws {
        try requireRemotePushE2E()

        let modelContainer = try SharedModelContainer.make()
        let modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false

        let existingConfigurations = try modelContext.fetch(FetchDescriptor<CryptoConfig>())
        for existingConfiguration in existingConfigurations {
            modelContext.delete(existingConfiguration)
        }

        let keychainConfiguration = try sharedKeychainConfiguration()
        try KeychainService.set(
            encryptionKey,
            forKey: keyReference,
            configuration: keychainConfiguration
        )
        try KeychainService.set(
            initializationVector,
            forKey: ivReference,
            configuration: keychainConfiguration
        )

        let serverID = try modelContext.fetch(FetchDescriptor<Server>()).first?.id ?? UUID()
        modelContext.insert(CryptoConfig(
            serverID: serverID,
            algorithm: .aes256,
            mode: .cbc,
            keychainKeyRef: keyReference,
            keychainIVRef: ivReference
        ))
        try modelContext.save()

        let storedBundle = try XCTUnwrap(CryptoSettingsStore(
            modelContainer: modelContainer,
            keychainConfig: keychainConfiguration
        ).currentBundle())
        XCTAssertEqual(storedBundle.algorithm, .aes256)
        XCTAssertEqual(storedBundle.mode, .cbc)
        XCTAssertEqual(storedBundle.key, encryptionKey)
        XCTAssertEqual(storedBundle.iv, initializationVector)
    }

    func testRemoveSharedCryptoKeyFixture() throws {
        try requireRemotePushE2E()

        let modelContainer = try SharedModelContainer.make()
        let keychainConfiguration = try sharedKeychainConfiguration()
        try KeychainService.delete(
            forKey: keyReference,
            configuration: keychainConfiguration
        )

        XCTAssertNil(try KeychainService.get(
            forKey: keyReference,
            configuration: keychainConfiguration
        ))
        XCTAssertNil(try CryptoSettingsStore(
            modelContainer: modelContainer,
            keychainConfig: keychainConfiguration
        ).currentBundle())
    }

    func testRemoveSharedCryptoFixture() throws {
        try requireRemotePushE2E()

        let modelContainer = try SharedModelContainer.make()
        let modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
        let keychainConfiguration = try sharedKeychainConfiguration()

        let existingConfigurations = try modelContext.fetch(FetchDescriptor<CryptoConfig>())
        for existingConfiguration in existingConfigurations {
            modelContext.delete(existingConfiguration)
        }
        try modelContext.save()

        try KeychainService.delete(
            forKey: keyReference,
            configuration: keychainConfiguration
        )
        try KeychainService.delete(
            forKey: ivReference,
            configuration: keychainConfiguration
        )

        XCTAssertTrue(try modelContext.fetch(FetchDescriptor<CryptoConfig>()).isEmpty)
        XCTAssertNil(try KeychainService.get(
            forKey: keyReference,
            configuration: keychainConfiguration
        ))
        XCTAssertNil(try KeychainService.get(
            forKey: ivReference,
            configuration: keychainConfiguration
        ))
    }

    private func sharedKeychainConfiguration() throws -> KeychainService.Configuration {
        let appIdentifierPrefix = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String
        )
        let teamID = appIdentifierPrefix.hasSuffix(".")
            ? String(appIdentifierPrefix.dropLast())
            : appIdentifierPrefix
        return .shared(teamID: teamID)
    }

    private func requireRemotePushE2E() throws {
        #if BARKAGENT_REMOTE_PUSH_E2E
        return
        #else
        try XCTSkipUnless(false, "Run through scripts/test-simulator-remote-push.sh.")
        #endif
    }
}
