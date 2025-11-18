//
//  HuggingChatUser.swift
//  HuggingChat-iOS
//

import Foundation

struct HuggingChatUser: Codable, Identifiable {
    let id: String
    let username: String
    let email: String
    let avatarUrl: String?
    let hfUserId: String
    let orgs: [Organization]?
    let isPro: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username
        case email
        case avatarUrl
        case hfUserId
        case orgs
        case isPro
    }

    struct Organization: Codable {
        let _id: String
        let name: String
        let avatarUrl: String?
    }
}

extension HuggingChatUser {
    static let preview = HuggingChatUser(
        id: "preview-id",
        username: "preview_user",
        email: "preview@example.com",
        avatarUrl: nil,
        hfUserId: "hf-preview-id",
        orgs: nil,
        isPro: false
    )
}
