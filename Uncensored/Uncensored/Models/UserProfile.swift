//
//  UserProfile.swift
//  Uncensored
//

import Foundation

struct UserProfile: Identifiable, Codable {
    let id: String          // Firestore document ID == Firebase Auth uid
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
