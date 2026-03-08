//
//  Comment.swift
//  Uncensored
//

import Foundation

struct Comment: Identifiable, Codable {
    let id: String
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
