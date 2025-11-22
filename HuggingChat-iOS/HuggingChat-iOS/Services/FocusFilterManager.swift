//
//  FocusFilterManager.swift
//  HuggingChat-iOS
//
//  Focus Filter support for iOS Focus modes
//

import Foundation
import AppIntents

// MARK: - Focus Filter

@available(iOS 16.0, *)
struct ConversationFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Filter Conversations"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Filter Conversations")
    }

    @Parameter(title: "Show Priority Conversations")
    var showPriorityOnly: Bool

    @Parameter(title: "Hide Notifications")
    var hideNotifications: Bool

    func perform() async throws -> some IntentResult {
        // Apply focus filter settings
        FocusFilterManager.shared.applyFilter(
            priorityOnly: showPriorityOnly,
            hideNotifications: hideNotifications
        )

        return .result()
    }
}

// MARK: - Focus Filter Manager

@Observable
final class FocusFilterManager: @unchecked Sendable {
    static let shared = FocusFilterManager()

    var isFilterActive = false
    var showPriorityOnly = false
    var hideNotifications = false

    private init() {}

    func applyFilter(priorityOnly: Bool, hideNotifications: Bool) {
        self.isFilterActive = true
        self.showPriorityOnly = priorityOnly
        self.hideNotifications = hideNotifications
    }

    func clearFilter() {
        self.isFilterActive = false
        self.showPriorityOnly = false
        self.hideNotifications = false
    }

    func shouldShowConversation(_ conversation: Conversation) -> Bool {
        if !isFilterActive {
            return true
        }

        if showPriorityOnly {
            // Show conversations from last 24 hours
            let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
            return conversation.updatedAt > oneDayAgo
        }

        return true
    }
}
