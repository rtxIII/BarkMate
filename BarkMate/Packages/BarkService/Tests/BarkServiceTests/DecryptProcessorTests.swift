import XCTest
import CryptoSwift
@testable import BarkService
import Models

final class DecryptProcessorTests: XCTestCase {

    private let key = Data("0123456789abcdef0123456789abcdef".utf8) // 32 bytes AES-256
    private let iv = Data("abcdef0123456789".utf8)                   // 16 bytes

    private var bundle: CryptoBundle {
        CryptoBundle(
            algorithm: .aes256,
            mode: .cbc,
            padding: .pkcs7,
            key: key,
            iv: iv
        )
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

    // MARK: - Tests

    func testNoCiphertextPassesThrough() {
        let userInfo: [AnyHashable: Any] = ["aps": ["alert": ["body": "plain"]]]
        let result = DecryptProcessor.decryptIfNeeded(userInfo: userInfo, bundle: bundle)
        XCTAssertFalse(result.decryptionFailed)
        XCTAssertNil(result.originalCiphertext)

        let aps = result.userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]
        XCTAssertEqual(alert?["body"] as? String, "plain")
    }

    func testSuccessfulDecryptMergesFields() throws {
        let ciphertext = try encrypt(
            ["title": "Hello", "body": "decrypted", "group": "work"],
            using: bundle
        )
        let userInfo: [AnyHashable: Any] = ["ciphertext": ciphertext]

        let result = DecryptProcessor.decryptIfNeeded(userInfo: userInfo, bundle: bundle)

        XCTAssertFalse(result.decryptionFailed)
        XCTAssertNil(result.userInfo["ciphertext"])

        let aps = result.userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]
        XCTAssertEqual(alert?["title"] as? String, "Hello")
        XCTAssertEqual(alert?["body"] as? String, "decrypted")
        XCTAssertEqual(result.userInfo["group"] as? String, "work")
    }

    func testWrongKeyProducesFailureWithOriginalCiphertextPreserved() throws {
        let encryptedWithCorrectKey = try encrypt(["body": "secret"], using: bundle)
        let wrongBundle = CryptoBundle(
            algorithm: .aes256,
            mode: .cbc,
            padding: .pkcs7,
            key: Data("wrong-key-padding-to-32-bytes!!!".utf8),
            iv: iv
        )
        let userInfo: [AnyHashable: Any] = ["ciphertext": encryptedWithCorrectKey]

        let result = DecryptProcessor.decryptIfNeeded(userInfo: userInfo, bundle: wrongBundle)

        XCTAssertTrue(result.decryptionFailed)
        XCTAssertEqual(result.originalCiphertext, encryptedWithCorrectKey)

        let aps = result.userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]
        XCTAssertEqual(alert?["body"] as? String, "Decryption Failed")
    }

    func testIVOverrideFromPayload() throws {
        let altIV = Data("fedcba9876543210".utf8)
        let altBundle = bundle.overriding(iv: altIV)
        let ciphertext = try encrypt(["body": "with-alt-iv"], using: altBundle)

        let userInfo: [AnyHashable: Any] = [
            "ciphertext": ciphertext,
            "iv": String(data: altIV, encoding: String.Encoding.utf8) ?? ""
        ]

        let result = DecryptProcessor.decryptIfNeeded(userInfo: userInfo, bundle: bundle)

        XCTAssertFalse(result.decryptionFailed)
        let aps = result.userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]
        XCTAssertEqual(alert?["body"] as? String, "with-alt-iv")
    }

    func testNoBundleWhenCiphertextPresentFails() {
        let userInfo: [AnyHashable: Any] = ["ciphertext": "any-base64=="]
        let result = DecryptProcessor.decryptIfNeeded(userInfo: userInfo, bundle: nil)

        XCTAssertTrue(result.decryptionFailed)
        XCTAssertEqual(result.originalCiphertext, "any-base64==")
    }
}
