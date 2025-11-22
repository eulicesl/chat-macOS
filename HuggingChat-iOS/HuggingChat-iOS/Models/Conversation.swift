//
//  Conversation.swift
//  HuggingChat-iOS
//

import Foundation

struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    let modelId: String
    var messages: [Message]
    var updatedAt: Date
    let createdAt: Date?
    var areMessagesLoaded: Bool
    var preprompt: String?
    var assistantId: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case modelId = "model"
        case messages
        case updatedAt
        case createdAt
        case preprompt
        case assistantId
    }

    // Memberwise initializer
    init(id: String, title: String, modelId: String, messages: [Message], updatedAt: Date, createdAt: Date?, areMessagesLoaded: Bool, preprompt: String?, assistantId: String?) {
        self.id = id
        self.title = title
        self.modelId = modelId
        self.messages = messages
        self.updatedAt = updatedAt
        self.createdAt = createdAt
        self.areMessagesLoaded = areMessagesLoaded
        self.preprompt = preprompt
        self.assistantId = assistantId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        modelId = try container.decode(String.self, forKey: .modelId)
        messages = (try? container.decode([Message].self, forKey: .messages)) ?? []

        // Handle date decoding with fallback
        if let dateString = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            updatedAt = Date()
        }

        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString)
        } else {
            createdAt = nil
        }

        areMessagesLoaded = messages.count > 0
        preprompt = try? container.decode(String.self, forKey: .preprompt)
        assistantId = try? container.decode(String.self, forKey: .assistantId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(modelId, forKey: .modelId)
        try container.encode(messages, forKey: .messages)
        try container.encode(ISO8601DateFormatter().string(from: updatedAt), forKey: .updatedAt)

        if let createdAt = createdAt {
            try container.encode(ISO8601DateFormatter().string(from: createdAt), forKey: .createdAt)
        }

        try container.encodeIfPresent(preprompt, forKey: .preprompt)
        try container.encodeIfPresent(assistantId, forKey: .assistantId)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }
}

extension Conversation {
    static let preview = Conversation(
        id: "preview-conv-id",
        title: "Preview Conversation",
        modelId: "meta-llama/Meta-Llama-3.1-70B-Instruct",
        messages: [],
        updatedAt: Date(),
        createdAt: Date(),
        areMessagesLoaded: false,
        preprompt: nil,
        assistantId: nil
    )
}
