//
//  UserProfile.swift
//  Uncensored
//

import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    var id: String          // Firestore document ID == Firebase Auth uid
    var username: String
    var displayName: String
    var bio: String
    var avatarURL: String?
    var followersCount: Int
    var followingCount: Int
    var videosCount: Int
    var isPrivate: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName
        case bio
        case avatarURL
        case followersCount
        case followingCount
        case videosCount
        case isPrivate
        case createdAt
    }

    init(id: String, username: String, displayName: String, bio: String,
         avatarURL: String? = nil, followersCount: Int, followingCount: Int,
         videosCount: Int, isPrivate: Bool, createdAt: Date) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.avatarURL = avatarURL
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.videosCount = videosCount
        self.isPrivate = isPrivate
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // id may be absent in documents created without storing the field;
        // fall back to a UUID to satisfy Identifiable and avoid SwiftUI identity conflicts.
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        username = (try? container.decode(String.self, forKey: .username)) ?? ""
        displayName = (try? container.decode(String.self, forKey: .displayName)) ?? ""
        bio = (try? container.decode(String.self, forKey: .bio)) ?? ""
        avatarURL = try? container.decode(String.self, forKey: .avatarURL)
        followersCount = (try? container.decode(Int.self, forKey: .followersCount)) ?? 0
        followingCount = (try? container.decode(Int.self, forKey: .followingCount)) ?? 0
        videosCount = (try? container.decode(Int.self, forKey: .videosCount)) ?? 0
        isPrivate = (try? container.decode(Bool.self, forKey: .isPrivate)) ?? false
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
    }

    /// Returns a minimal profile stub for first-time login (before username is set).
    static func stub(uid: String) -> UserProfile {
        UserProfile(
            id: uid,
            username: "",
            displayName: "",
            bio: "",
            avatarURL: nil,
            followersCount: 0,
            followingCount: 0,
            videosCount: 0,
            isPrivate: false,
            createdAt: Date()
        )
    }
}
