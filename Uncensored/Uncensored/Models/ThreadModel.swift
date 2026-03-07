//
//  ThreadModel.swift
//  Uncensored
//

import Foundation

struct ThreadModel: Identifiable, Codable {
    let id: String          // Firestore document ID
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
}

struct ThreadReply: Identifiable, Codable {
    let id: String
    let authorId: String
    var authorUsername: String
    var body: String
    var likesCount: Int
    let createdAt: Date
}
