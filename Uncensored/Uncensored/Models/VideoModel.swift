//
//  VideoModel.swift
//  Uncensored
//

import Foundation

struct VideoModel: Identifiable, Codable {
    let id: String          // Firestore document ID
    let authorId: String
    var videoURL: String
    var thumbnailURL: String?
    var caption: String
    var likesCount: Int
    var commentsCount: Int
    var sharesCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorId
        case videoURL
        case thumbnailURL
        case caption
        case likesCount
        case commentsCount
        case sharesCount
        case createdAt
    }
}
