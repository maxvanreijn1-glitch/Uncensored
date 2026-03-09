//
//  Comment.swift
//  Uncensored
//

import Foundation

struct Comment: Identifiable, Codable {
    var id: String
    let authorId: String
    var authorUsername: String
    var body: String
    var likesCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorId
        case authorUsername
        case body
        case likesCount
        case createdAt
    }

    init(id: String, authorId: String, authorUsername: String, body: String,
         likesCount: Int, createdAt: Date) {
        self.id = id
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.body = body
        self.likesCount = likesCount
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        authorId = try container.decode(String.self, forKey: .authorId)
        authorUsername = (try? container.decode(String.self, forKey: .authorUsername)) ?? ""
        body = try container.decode(String.self, forKey: .body)
        likesCount = (try? container.decode(Int.self, forKey: .likesCount)) ?? 0
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
    }
}

struct Follow: Identifiable, Codable {
    var id: String { "\(follower)_\(following)" }
    let follower: String   // uid of the follower
    let following: String  // uid of the person being followed
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case follower
        case following
        case createdAt
    }
}
