//
//  ThreadModel.swift
//  Uncensored
//

import Foundation

struct ThreadModel: Identifiable, Codable {
    var id: String          // Firestore document ID
    let authorId: String
    var authorUsername: String
    var body: String
    var likesCount: Int
    var repliesCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorId
        case authorUsername
        case body
        case likesCount
        case repliesCount
        case createdAt
    }

    init(id: String, authorId: String, authorUsername: String, body: String,
         likesCount: Int, repliesCount: Int, createdAt: Date) {
        self.id = id
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.body = body
        self.likesCount = likesCount
        self.repliesCount = repliesCount
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // id may be absent in documents created without storing the field;
        // fall back to a UUID to satisfy Identifiable and avoid SwiftUI identity conflicts.
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        authorId = try container.decode(String.self, forKey: .authorId)
        authorUsername = (try? container.decode(String.self, forKey: .authorUsername)) ?? ""
        body = try container.decode(String.self, forKey: .body)
        likesCount = (try? container.decode(Int.self, forKey: .likesCount)) ?? 0
        repliesCount = (try? container.decode(Int.self, forKey: .repliesCount)) ?? 0
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
    }
}

struct ThreadReply: Identifiable, Codable {
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
