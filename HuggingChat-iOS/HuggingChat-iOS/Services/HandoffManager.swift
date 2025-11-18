//
//  HandoffManager.swift
//  HuggingChat-iOS
//
//  Handoff support for continuity across Apple devices
//

import Foundation

@Observable
class HandoffManager {
    static let shared = HandoffManager()

    private var currentActivity: NSUserActivity?

    private init() {}

    // MARK: - Start Handoff

    func startHandoff(for conversation: Conversation) {
        let activity = NSUserActivity(activityType: "com.huggingface.huggingchat.conversation")

        activity.title = conversation.title
        activity.userInfo = [
            "conversationId": conversation.id,
            "modelId": conversation.modelId,
            "title": conversation.title
        ]

        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true

        // Add searchable attributes
        let attributes = NSMutableSet()
        attributes.add("chat")
        attributes.add("conversation")
        activity.keywords = attributes as? Set<String> ?? []

        activity.becomeCurrent()

        currentActivity = activity
    }

    func updateHandoff(with message: String) {
        guard let activity = currentActivity else { return }

        var userInfo = activity.userInfo ?? [:]
        userInfo["lastMessage"] = message
        userInfo["lastUpdated"] = Date()

        activity.userInfo = userInfo
        activity.needsSave = true
    }

    func stopHandoff() {
        currentActivity?.invalidate()
        currentActivity = nil
    }

    // MARK: - Continue Activity

    static func continueActivity(_ userActivity: NSUserActivity) -> String? {
        guard userActivity.activityType == "com.huggingface.huggingchat.conversation" else {
            return nil
        }

        return userActivity.userInfo?["conversationId"] as? String
    }
}
