//
//  UserAgentBuilderTests.swift
//  HuggingChat-MacTests
//
//  Created by Claude Code on production readiness improvements
//

import XCTest
@testable import HuggingChat_Mac

final class UserAgentBuilderTests: XCTestCase {

    // MARK: - User Agent String Tests

    func testUserAgentStringNotEmpty() {
        // When
        let userAgent = UserAgentBuilder.userAgent

        // Then
        XCTAssertFalse(userAgent.isEmpty, "User agent should not be empty")
    }

    func testUserAgentContainsAppName() {
        // When
        let userAgent = UserAgentBuilder.userAgent

        // Then
        XCTAssertTrue(userAgent.contains("HuggingChat-Mac") || userAgent.contains("/"),
                     "User agent should contain app name or version separator")
    }

    func testUserAgentContainsVersion() {
        // When
        let appVersion = UserAgentBuilder.appVersion

        // Then
        XCTAssertFalse(appVersion.isEmpty, "App version should not be empty")
        XCTAssertNotEqual(appVersion, "1.0.0", "App version should not be default fallback in production")
    }

    func testBuildNumberNotEmpty() {
        // When
        let buildNumber = UserAgentBuilder.buildNumber

        // Then
        XCTAssertFalse(buildNumber.isEmpty, "Build number should not be empty")
        XCTAssertNotEqual(buildNumber, "1", "Build number should not be default fallback in production")
    }

    // MARK: - System Information Tests

    func testDarwinVersionFormat() {
        // When
        let darwinVersion = UserAgentBuilder.DarwinVersion()

        // Then
        XCTAssertTrue(darwinVersion.hasPrefix("Darwin/"), "Darwin version should start with 'Darwin/'")
        XCTAssertGreaterThan(darwinVersion.count, 7, "Darwin version should have version number")
    }

    func testCFNetworkVersionFormat() {
        // When
        let cfNetworkVersion = UserAgentBuilder.CFNetworkVersion()

        // Then
        XCTAssertTrue(cfNetworkVersion.hasPrefix("CFNetwork/") || cfNetworkVersion == "CFNetwork/Unknown",
                     "CFNetwork version should start with 'CFNetwork/' or be unknown")
    }

    func testDeviceNameNotEmpty() {
        // When
        let deviceName = UserAgentBuilder.deviceName()

        // Then
        XCTAssertFalse(deviceName.isEmpty, "Device name should not be empty")
        XCTAssertNotEqual(deviceName, "Unknown", "Device name should be detected")
    }

    func testDeviceVersionNotEmpty() {
        // When
        let deviceVersion = UserAgentBuilder.deviceVersion()

        // Then
        XCTAssertFalse(deviceVersion.isEmpty, "Device version should not be empty")
    }

    func testOSVersionFormat() {
        // When
        let osVersion = UserAgentBuilder.osVersion

        // Then
        XCTAssertTrue(osVersion.hasPrefix("macOS"), "OS version should start with 'macOS'")
        XCTAssertTrue(osVersion.contains("."), "OS version should contain version number with dot")
    }

    // MARK: - Consistency Tests

    func testUserAgentConsistency() {
        // When
        let userAgent1 = UserAgentBuilder.userAgent
        let userAgent2 = UserAgentBuilder.userAgent

        // Then
        XCTAssertEqual(userAgent1, userAgent2, "User agent should be consistent across calls")
    }

    func testAppVersionConsistency() {
        // When
        let version1 = UserAgentBuilder.appVersion
        let version2 = UserAgentBuilder.appVersion

        // Then
        XCTAssertEqual(version1, version2, "App version should be consistent")
    }

    func testDeviceConsistency() {
        // When
        let device1 = UserAgentBuilder.device
        let device2 = UserAgentBuilder.device

        // Then
        XCTAssertEqual(device1, device2, "Device should be consistent")
    }

    // MARK: - Format Validation Tests

    func testAppNameAndVersionFormat() {
        // When
        let appNameAndVersion = UserAgentBuilder.appNameAndVersion()

        // Then
        XCTAssertTrue(appNameAndVersion.contains("/"), "Should contain / separator")
        XCTAssertTrue(appNameAndVersion.contains("(") || appNameAndVersion.contains("-"),
                     "Should contain build number with separator")
    }

    func testUserAgentDoesNotContainInvalidCharacters() {
        // When
        let userAgent = UserAgentBuilder.userAgent

        // Then
        XCTAssertFalse(userAgent.contains("\n"), "User agent should not contain newlines")
        XCTAssertFalse(userAgent.contains("\r"), "User agent should not contain carriage returns")
    }

    // MARK: - Performance Tests

    func testUserAgentPerformance() {
        measure {
            _ = UserAgentBuilder.userAgent
        }
    }

    func testSystemInfoPerformance() {
        measure {
            _ = UserAgentBuilder.deviceName()
            _ = UserAgentBuilder.deviceVersion()
            _ = UserAgentBuilder.DarwinVersion()
        }
    }
}
