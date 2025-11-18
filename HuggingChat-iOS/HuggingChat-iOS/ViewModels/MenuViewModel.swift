//
//  MenuViewModel.swift
//  HuggingChat-iOS
//

import Foundation
import Observation

@Observable
class MenuViewModel {
    var conversations: [String: [Conversation]] = [:]
    var currentConversationId: String?
    var isLoading = false
    var errorMessage: String?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    func getConversations() async {
        isLoading = true

        do {
            let fetchedConversations = try await NetworkService.shared.getConversations()

            await MainActor.run {
                HuggingChatSession.shared.conversations = fetchedConversations
                self.groupConversationsByDate(fetchedConversations)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func refreshConversations() async {
        await getConversations()
    }

    private func groupConversationsByDate(_ conversations: [Conversation]) {
        let calendar = Calendar.current
        let now = Date()

        var grouped: [String: [Conversation]] = [
            "Today": [],
            "Yesterday": [],
            "This Week": [],
            "This Month": [],
            "Older": []
        ]

        for conversation in conversations {
            let conversationDate = conversation.updatedAt

            if calendar.isDateInToday(conversationDate) {
                grouped["Today"]?.append(conversation)
            } else if calendar.isDateInYesterday(conversationDate) {
                grouped["Yesterday"]?.append(conversation)
            } else if calendar.isDate(conversationDate, equalTo: now, toGranularity: .weekOfYear) {
                grouped["This Week"]?.append(conversation)
            } else if calendar.isDate(conversationDate, equalTo: now, toGranularity: .month) {
                grouped["This Month"]?.append(conversation)
            } else {
                grouped["Older"]?.append(conversation)
            }
        }

        // Remove empty sections
        self.conversations = grouped.filter { !$0.value.isEmpty }
    }

    func deleteConversation(_ conversation: Conversation) async {
        do {
            try await NetworkService.shared.deleteConversation(id: conversation.id)

            await MainActor.run {
                HuggingChatSession.shared.conversations.removeAll { $0.id == conversation.id }
                self.groupConversationsByDate(HuggingChatSession.shared.conversations)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
