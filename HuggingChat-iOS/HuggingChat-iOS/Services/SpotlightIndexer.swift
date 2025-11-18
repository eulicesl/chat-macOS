//
//  SpotlightIndexer.swift
//  HuggingChat-iOS
//
//  Spotlight search integration for conversations
//

import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers

@Observable
class SpotlightIndexer {
    static let shared = SpotlightIndexer()

    private init() {}

    // MARK: - Index Conversations

    func indexConversation(_ conversation: Conversation) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)

        // Basic attributes
        attributeSet.title = conversation.title
        attributeSet.contentDescription = "Conversation with \(conversation.modelId.split(separator: "/").last ?? "AI")"
        attributeSet.keywords = ["chat", "conversation", "AI", "HuggingChat"]

        // Dates
        attributeSet.contentModificationDate = conversation.updatedAt
        if let createdAt = conversation.createdAt {
            attributeSet.contentCreationDate = createdAt
        }

        // Custom metadata
        attributeSet.identifier = conversation.id
        attributeSet.relatedUniqueIdentifier = conversation.id

        // Thumbnail
        attributeSet.thumbnailData = generateConversationThumbnail()

        // Create searchable item
        let item = CSSearchableItem(
            uniqueIdentifier: "conversation-\(conversation.id)",
            domainIdentifier: "conversations",
            attributeSet: attributeSet
        )

        // Set expiration (30 days)
        item.expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)

        // Index
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Failed to index conversation: \(error)")
            }
        }
    }

    func indexConversations(_ conversations: [Conversation]) {
        let items = conversations.map { conversation -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .content)

            attributeSet.title = conversation.title
            attributeSet.contentDescription = "Conversation with \(conversation.modelId.split(separator: "/").last ?? "AI")"
            attributeSet.keywords = ["chat", "conversation", "AI", "HuggingChat"]
            attributeSet.contentModificationDate = conversation.updatedAt
            attributeSet.identifier = conversation.id
            attributeSet.thumbnailData = generateConversationThumbnail()

            let item = CSSearchableItem(
                uniqueIdentifier: "conversation-\(conversation.id)",
                domainIdentifier: "conversations",
                attributeSet: attributeSet
            )

            item.expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)

            return item
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                print("Failed to index conversations: \(error)")
            }
        }
    }

    // MARK: - Remove from Index

    func removeConversation(_ conversationId: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["conversation-\(conversationId)"]) { error in
            if let error = error {
                print("Failed to remove conversation from index: \(error)")
            }
        }
    }

    func clearAllConversations() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["conversations"]) { error in
            if let error = error {
                print("Failed to clear conversations from index: \(error)")
            }
        }
    }

    // MARK: - Search

    func searchConversations(query: String, completion: @escaping ([String]) -> Void) {
        let queryString = "title == \"*\(query)*\"c || contentDescription == \"*\(query)*\"c"
        let searchQuery = CSSearchQuery(queryString: queryString, attributes: ["title", "identifier"])

        var foundIdentifiers: [String] = []

        searchQuery.foundItemsHandler = { items in
            foundIdentifiers.append(contentsOf: items.map { $0.uniqueIdentifier })
        }

        searchQuery.completionHandler = { error in
            if let error = error {
                print("Search error: \(error)")
            }
            completion(foundIdentifiers)
        }

        searchQuery.start()
    }

    // MARK: - Helpers

    private func generateConversationThumbnail() -> Data? {
        let size = CGSize(width: 128, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            // Background
            UIColor.systemCyan.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Icon
            let config = UIImage.SymbolConfiguration(pointSize: 64, weight: .regular)
            let icon = UIImage(systemName: "message.fill", withConfiguration: config)

            UIColor.white.setFill()
            icon?.draw(in: CGRect(x: 32, y: 32, width: 64, height: 64))
        }

        return image.pngData()
    }
}
