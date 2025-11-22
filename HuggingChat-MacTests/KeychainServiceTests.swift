//
//  KeychainServiceTests.swift
//  HuggingChat-MacTests
//
//  Created by Claude Code on production readiness improvements
//

import XCTest
@testable import HuggingChat_Mac

final class KeychainServiceTests: XCTestCase {

    var keychainService: KeychainService!

    override func setUp() {
        super.setUp()
        keychainService = KeychainService.shared
        // Clean up any existing test data
        keychainService.deleteAll()
    }

    override func tearDown() {
        // Clean up after tests
        keychainService.deleteAll()
        super.tearDown()
    }

    // MARK: - Basic Operations Tests

    func testSaveAndRetrieveToken() {
        // Given
        let testToken = "test-token-12345"
        let key = KeychainService.KeychainKey.authToken

        // When
        let saveResult = keychainService.save(testToken, for: key)
        let retrievedToken = keychainService.retrieve(for: key)

        // Then
        XCTAssertTrue(saveResult, "Save should succeed")
        XCTAssertEqual(retrievedToken, testToken, "Retrieved token should match saved token")
    }

    func testSaveMultipleKeys() {
        // Given
        let authToken = "auth-token-123"
        let chatToken = "chat-token-456"
        let clientID = "client-id-789"

        // When
        keychainService.save(authToken, for: .authToken)
        keychainService.save(chatToken, for: .hfChatToken)
        keychainService.save(clientID, for: .clientID)

        // Then
        XCTAssertEqual(keychainService.retrieve(for: .authToken), authToken)
        XCTAssertEqual(keychainService.retrieve(for: .hfChatToken), chatToken)
        XCTAssertEqual(keychainService.retrieve(for: .clientID), clientID)
    }

    func testUpdateExistingKey() {
        // Given
        let key = KeychainService.KeychainKey.authToken
        let originalToken = "original-token"
        let updatedToken = "updated-token"

        // When
        keychainService.save(originalToken, for: key)
        keychainService.save(updatedToken, for: key)
        let retrievedToken = keychainService.retrieve(for: key)

        // Then
        XCTAssertEqual(retrievedToken, updatedToken, "Should retrieve updated token")
        XCTAssertNotEqual(retrievedToken, originalToken, "Should not retrieve original token")
    }

    func testDeleteKey() {
        // Given
        let key = KeychainService.KeychainKey.authToken
        keychainService.save("test-token", for: key)

        // When
        let deleteResult = keychainService.delete(for: key)
        let retrievedToken = keychainService.retrieve(for: key)

        // Then
        XCTAssertTrue(deleteResult, "Delete should succeed")
        XCTAssertNil(retrievedToken, "Token should be nil after deletion")
    }

    func testDeleteNonExistentKey() {
        // Given
        let key = KeychainService.KeychainKey.authToken

        // When
        let deleteResult = keychainService.delete(for: key)

        // Then
        XCTAssertTrue(deleteResult, "Delete should succeed even if key doesn't exist")
    }

    func testDeleteAll() {
        // Given
        keychainService.save("token1", for: .authToken)
        keychainService.save("token2", for: .hfChatToken)
        keychainService.save("id", for: .clientID)

        // When
        let deleteAllResult = keychainService.deleteAll()

        // Then
        XCTAssertTrue(deleteAllResult, "DeleteAll should succeed")
        XCTAssertNil(keychainService.retrieve(for: .authToken))
        XCTAssertNil(keychainService.retrieve(for: .hfChatToken))
        XCTAssertNil(keychainService.retrieve(for: .clientID))
    }

    func testKeyExists() {
        // Given
        let key = KeychainService.KeychainKey.authToken

        // When
        let existsBeforeSave = keychainService.exists(for: key)
        keychainService.save("test-token", for: key)
        let existsAfterSave = keychainService.exists(for: key)

        // Then
        XCTAssertFalse(existsBeforeSave, "Key should not exist before save")
        XCTAssertTrue(existsAfterSave, "Key should exist after save")
    }

    // MARK: - Edge Cases Tests

    func testSaveEmptyString() {
        // Given
        let emptyString = ""
        let key = KeychainService.KeychainKey.authToken

        // When
        let saveResult = keychainService.save(emptyString, for: key)
        let retrievedValue = keychainService.retrieve(for: key)

        // Then
        XCTAssertTrue(saveResult, "Should be able to save empty string")
        XCTAssertEqual(retrievedValue, emptyString, "Should retrieve empty string")
    }

    func testSaveVeryLongString() {
        // Given
        let longString = String(repeating: "a", count: 10000)
        let key = KeychainService.KeychainKey.authToken

        // When
        let saveResult = keychainService.save(longString, for: key)
        let retrievedValue = keychainService.retrieve(for: key)

        // Then
        XCTAssertTrue(saveResult, "Should be able to save long string")
        XCTAssertEqual(retrievedValue, longString, "Should retrieve full long string")
    }

    func testSaveSpecialCharacters() {
        // Given
        let specialString = "!@#$%^&*()_+-=[]{}|;':\",./<>?`~\n\t"
        let key = KeychainService.KeychainKey.authToken

        // When
        keychainService.save(specialString, for: key)
        let retrievedValue = keychainService.retrieve(for: key)

        // Then
        XCTAssertEqual(retrievedValue, specialString, "Should handle special characters")
    }

    func testSaveUnicodeCharacters() {
        // Given
        let unicodeString = "こんにちは 🚀 مرحبا"
        let key = KeychainService.KeychainKey.authToken

        // When
        keychainService.save(unicodeString, for: key)
        let retrievedValue = keychainService.retrieve(for: key)

        // Then
        XCTAssertEqual(retrievedValue, unicodeString, "Should handle unicode characters")
    }

    // MARK: - Performance Tests

    func testSavePerformance() {
        measure {
            for i in 0..<100 {
                keychainService.save("token-\(i)", for: .authToken)
            }
        }
    }

    func testRetrievePerformance() {
        keychainService.save("test-token", for: .authToken)

        measure {
            for _ in 0..<100 {
                _ = keychainService.retrieve(for: .authToken)
            }
        }
    }
}
