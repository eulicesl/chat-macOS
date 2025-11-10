//
//  AppLoggerTests.swift
//  HuggingChat-MacTests
//
//  Created by Claude Code on production readiness improvements
//

import XCTest
@testable import HuggingChat_Mac

final class AppLoggerTests: XCTestCase {

    // MARK: - Logger Category Tests

    func testNetworkLoggerExists() {
        // When/Then
        XCTAssertNotNil(AppLogger.network, "Network logger should exist")
    }

    func testAuthLoggerExists() {
        // When/Then
        XCTAssertNotNil(AppLogger.auth, "Auth logger should exist")
    }

    func testAudioLoggerExists() {
        // When/Then
        XCTAssertNotNil(AppLogger.audio, "Audio logger should exist")
    }

    func testModelLoggerExists() {
        // When/Then
        XCTAssertNotNil(AppLogger.model, "Model logger should exist")
    }

    func testConversationLoggerExists() {
        // When/Then
        XCTAssertNotNil(AppLogger.conversation, "Conversation logger should exist")
    }

    func testUILoggerExists() {
        // When/Then
        XCTAssertNotNil(AppLogger.ui, "UI logger should exist")
    }

    func testGeneralLoggerExists() {
        // When/Then
        XCTAssertNotNil(AppLogger.general, "General logger should exist")
    }

    func testFileLoggerExists() {
        // When/Then
        XCTAssertNotNil(AppLogger.file, "File logger should exist")
    }

    // MARK: - Logging Methods Tests

    func testInfoLogging() {
        // Given/When
        XCTAssertNoThrow(AppLogger.info("Test info message"), "Info logging should not throw")
    }

    func testDebugLogging() {
        // Given/When
        XCTAssertNoThrow(AppLogger.debug("Test debug message"), "Debug logging should not throw")
    }

    func testWarningLogging() {
        // Given/When
        XCTAssertNoThrow(AppLogger.warning("Test warning message"), "Warning logging should not throw")
    }

    func testErrorLogging() {
        // Given/When
        XCTAssertNoThrow(AppLogger.error("Test error message"), "Error logging should not throw")
    }

    func testErrorLoggingWithError() {
        // Given
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        // When/Then
        XCTAssertNoThrow(AppLogger.error("Test error message", error: error),
                        "Error logging with error object should not throw")
    }

    func testCriticalLogging() {
        // Given/When
        XCTAssertNoThrow(AppLogger.critical("Test critical message"), "Critical logging should not throw")
    }

    func testCriticalLoggingWithError() {
        // Given
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Critical error"])

        // When/Then
        XCTAssertNoThrow(AppLogger.critical("Test critical message", error: error),
                        "Critical logging with error should not throw")
    }

    // MARK: - Category-Specific Logging Tests

    func testNetworkRequestLogging() {
        // When/Then
        XCTAssertNoThrow(AppLogger.logNetworkRequest(endpoint: "/api/test", method: "GET"),
                        "Network request logging should not throw")
    }

    func testNetworkResponseLogging() {
        // When/Then
        XCTAssertNoThrow(AppLogger.logNetworkResponse(endpoint: "/api/test", statusCode: 200),
                        "Network response logging should not throw")
        XCTAssertNoThrow(AppLogger.logNetworkResponse(endpoint: "/api/test", statusCode: 404),
                        "Network error response logging should not throw")
    }

    func testAuthLogging() {
        // When/Then
        XCTAssertNoThrow(AppLogger.logAuth(event: "User login", success: true),
                        "Successful auth logging should not throw")
        XCTAssertNoThrow(AppLogger.logAuth(event: "User login", success: false),
                        "Failed auth logging should not throw")
    }

    // MARK: - Category Parameter Tests

    func testLoggingWithDifferentCategories() {
        // When/Then
        XCTAssertNoThrow(AppLogger.info("Network message", category: .network))
        XCTAssertNoThrow(AppLogger.info("Auth message", category: .auth))
        XCTAssertNoThrow(AppLogger.info("Audio message", category: .audio))
        XCTAssertNoThrow(AppLogger.info("Model message", category: .model))
        XCTAssertNoThrow(AppLogger.info("Conversation message", category: .conversation))
        XCTAssertNoThrow(AppLogger.info("UI message", category: .ui))
        XCTAssertNoThrow(AppLogger.info("File message", category: .file))
    }

    // MARK: - Edge Cases Tests

    func testLoggingEmptyString() {
        // When/Then
        XCTAssertNoThrow(AppLogger.info(""), "Should handle empty string logging")
    }

    func testLoggingLongString() {
        // Given
        let longMessage = String(repeating: "a", count: 10000)

        // When/Then
        XCTAssertNoThrow(AppLogger.info(longMessage), "Should handle long string logging")
    }

    func testLoggingSpecialCharacters() {
        // Given
        let specialMessage = "Test !@#$%^&*()_+-=[]{}|;':\",./<>?`~\n\t"

        // When/Then
        XCTAssertNoThrow(AppLogger.info(specialMessage), "Should handle special characters")
    }

    func testLoggingUnicodeCharacters() {
        // Given
        let unicodeMessage = "Test こんにちは 🚀 مرحبا"

        // When/Then
        XCTAssertNoThrow(AppLogger.info(unicodeMessage), "Should handle unicode characters")
    }

    // MARK: - Performance Tests

    func testInfoLoggingPerformance() {
        measure {
            for _ in 0..<100 {
                AppLogger.info("Performance test message")
            }
        }
    }

    func testCategoryLoggingPerformance() {
        measure {
            for _ in 0..<100 {
                AppLogger.info("Network performance test", category: .network)
            }
        }
    }

    func testErrorLoggingPerformance() {
        let error = NSError(domain: "test", code: 1, userInfo: nil)

        measure {
            for _ in 0..<100 {
                AppLogger.error("Error performance test", error: error)
            }
        }
    }
}
