//
//  Message.swift
//  HuggingChat-iOS
//

import Foundation

struct Message: Codable, Identifiable, Hashable {
    let id: String
    var content: String
    let author: Author
    let createdAt: Date?
    let updatedAt: Date?
    var webSearch: MessageWebSearch?
    var files: [String]?
    var interrupted: Bool?

    enum Author: String, Codable {
        case user
        case assistant
        case system
    }

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case author = "from"
        case createdAt
        case updatedAt
        case webSearch
        case files
        case interrupted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        author = try container.decode(Author.self, forKey: .author)

        // Handle date decoding with fallback
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString)
        } else {
            createdAt = nil
        }

        if let dateString = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = ISO8601DateFormatter().date(from: dateString)
        } else {
            updatedAt = nil
        }

        webSearch = try? container.decode(MessageWebSearch.self, forKey: .webSearch)
        files = try? container.decode([String].self, forKey: .files)
        interrupted = try? container.decode(Bool.self, forKey: .interrupted)
    }

    init(id: String = UUID().uuidString, content: String, author: Author, createdAt: Date? = Date(), updatedAt: Date? = nil, webSearch: MessageWebSearch? = nil, files: [String]? = nil) {
        self.id = id
        self.content = content
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.webSearch = webSearch
        self.files = files
        self.interrupted = nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

struct MessageWebSearch: Codable {
    let messages: [SearchMessage]?
    let sources: [WebSearchSource]?

    struct SearchMessage: Codable {
        let type: String
        let message: String?
        let args: [String]?
    }
}

struct WebSearchSource: Codable, Identifiable {
    let link: String
    let title: String
    let hostname: String

    var id: String { link }
}

// Message Row for display
struct MessageRow: Identifiable, Equatable {
    let id: String
    var content: String
    let type: MessageType
    var isInteracting: Bool
    var webSearch: MessageWebSearch?
    var files: [String]?
    let createdAt: Date?

    enum MessageType {
        case user
        case assistant
        case system
    }

    static func == (lhs: MessageRow, rhs: MessageRow) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content && lhs.isInteracting == rhs.isInteracting
    }
}
