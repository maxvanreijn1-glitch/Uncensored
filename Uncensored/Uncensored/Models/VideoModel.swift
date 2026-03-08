//
//  VideoModel.swift
//  Uncensored
//

import Foundation

struct VideoModel: Identifiable, Codable {
    let id: String          // Firestore document ID
    let authorId: String
    var authorUsername: String
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
        case authorUsername
        case videoURL
        case thumbnailURL
        case caption
        case likesCount
        case commentsCount
        case sharesCount
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorUsername = (try? container.decode(String.self, forKey: .authorUsername)) ?? ""
        videoURL = try container.decode(String.self, forKey: .videoURL)
        thumbnailURL = try? container.decode(String.self, forKey: .thumbnailURL)
        caption = try container.decode(String.self, forKey: .caption)
        likesCount = try container.decode(Int.self, forKey: .likesCount)
        commentsCount = try container.decode(Int.self, forKey: .commentsCount)
        sharesCount = try container.decode(Int.self, forKey: .sharesCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    init(id: String, authorId: String, authorUsername: String = "", videoURL: String,
         thumbnailURL: String? = nil, caption: String, likesCount: Int,
         commentsCount: Int, sharesCount: Int, createdAt: Date) {
        self.id = id
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.caption = caption
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.sharesCount = sharesCount
        self.createdAt = createdAt
    }
}
