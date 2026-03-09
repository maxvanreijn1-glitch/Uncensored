//
//  AuthViewModel.swift
//  Uncensored
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// Represents the current authentication and profile state of the app.
enum AuthState: Equatable {
    case loading
    case signedOut
    case needsUsername(uid: String)
    case signedIn(profile: UserProfile)
}

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var authState: AuthState = .loading

    /// Returns the signed-in user's UID, or nil if not signed in.
    var currentUserId: String? {
        if case .signedIn(let profile) = authState { return profile.id }
        return nil
    }

    /// Returns the signed-in user's username, or an empty string if not signed in.
    var currentUsername: String {
        if case .signedIn(let profile) = authState { return profile.username }
        return ""
    }

    /// Returns the signed-in user's full profile, or nil if not signed in.
    var currentProfile: UserProfile? {
        if case .signedIn(let profile) = authState { return profile }
        return nil
    }

    private let auth = FirebaseManager.shared.auth
    private let firestore = FirebaseManager.shared.firestore
    private let storage = FirebaseManager.shared.storage

    // A reference-type box that holds the Firebase auth state listener handle.
    // @unchecked Sendable is safe here because value is written exactly once (in
    // listenToAuthState, on the MainActor) and read exactly once (in deinit, when no
    // other references to self remain). There is no concurrent access scenario.
    private final class AuthListenerHandleBox: @unchecked Sendable {
        var value: AuthStateDidChangeListenerHandle?
    }
    // nonisolated let so that the nonisolated deinit can access the box directly.
    nonisolated private let handleBox = AuthListenerHandleBox()

    init() {
        listenToAuthState()
    }

    deinit {
        if let handle = handleBox.value {
            // Use Auth.auth() directly so deinit doesn't need to hop to the main actor.
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth state listener

    private func listenToAuthState() {
        handleBox.value = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                if let user {
                    await self.fetchOrCreateProfile(for: user)
                } else {
                    self.authState = .signedOut
                }
            }
        }
    }

    private func fetchOrCreateProfile(for user: FirebaseAuth.User) async {
        let uid = user.uid
        let docRef = firestore.collection("users").document(uid)
        do {
            let snapshot = try await docRef.getDocument()
            if snapshot.exists, let profile = try? snapshot.data(as: UserProfile.self) {
                if profile.username.isEmpty {
                    authState = .needsUsername(uid: uid)
                } else {
                    authState = .signedIn(profile: profile)
                }
            } else {
                // First login – create a stub document so setData(merge:) can later update it.
                let stub = UserProfile.stub(uid: uid)
                // The Codable setData overload is synchronous (fire-and-forget); the write is
                // enqueued locally and committed to the server in the background by the SDK.
                try? docRef.setData(from: stub)
                authState = .needsUsername(uid: uid)
            }
        } catch {
            // On error, default to needing username setup so the user can try again
            authState = .needsUsername(uid: uid)
        }
    }

    // MARK: - Profile setup (username + display name + bio + optional avatar)

    func saveProfile(
        username: String,
        displayName: String,
        bio: String,
        avatarData: Data?
    ) async throws {
        guard case .needsUsername(let uid) = authState else {
            throw ProfileSaveError.invalidState
        }

        let docRef = firestore.collection("users").document(uid)

        // Write text profile fields immediately so the account is usable.
        // Use setData(merge: true) so it works even if the stub document write failed.
        let profileData: [String: Any] = [
            "username": username,
            "displayName": displayName,
            "bio": bio,
        ]
        try await docRef.setData(profileData, merge: true)

        // ✅ FIX: Build profile locally instead of fetching from Firestore (eliminates hang)
        var profile = UserProfile.stub(uid: uid)
        profile.username = username
        profile.displayName = displayName
        profile.bio = bio
        authState = .signedIn(profile: profile)

        // Upload avatar in the background — does NOT block profile completion.
        if let data = avatarData {
            Task { @MainActor in
                do {
                    let storageRef = storage.reference().child("avatars/\(uid).jpg")
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    _ = try await storageRef.putDataAsync(data, metadata: metadata)
                    let downloadURL = try await storageRef.downloadURL()
                    let avatarURL = downloadURL.absoluteString
                    // Use setData(merge:) so the update works even if prior writes are incomplete.
                    try? await docRef.setData(["avatarURL": avatarURL], merge: true)
                    // Patch the in-memory profile with the uploaded URL.
                    if case .signedIn(var currentProfile) = self.authState, currentProfile.id == uid {
                        currentProfile.avatarURL = avatarURL
                        self.authState = .signedIn(profile: currentProfile)
                    }
                } catch {
                    // Avatar upload failed, but profile is already complete.
                    print("Avatar upload failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Profile update (edit existing profile)

    func updateProfile(
        displayName: String,
        bio: String,
        isPrivate: Bool,
        avatarData: Data?
    ) async throws {
        guard case .signedIn(var profile) = authState else {
            throw ProfileSaveError.invalidState
        }
        let uid = profile.id
        let docRef = firestore.collection("users").document(uid)

        let profileData: [String: Any] = [
            "displayName": displayName,
            "bio": bio,
            "isPrivate": isPrivate,
        ]
        try await docRef.setData(profileData, merge: true)

        // Update the in-memory profile immediately.
        profile.displayName = displayName
        profile.bio = bio
        profile.isPrivate = isPrivate
        authState = .signedIn(profile: profile)

        // Upload avatar in the background — does NOT block profile completion.
        if let data = avatarData {
            Task { @MainActor in
                do {
                    let storageRef = storage.reference().child("avatars/\(uid).jpg")
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    _ = try await storageRef.putDataAsync(data, metadata: metadata)
                    let downloadURL = try await storageRef.downloadURL()
                    let avatarURL = downloadURL.absoluteString
                    try? await docRef.setData(["avatarURL": avatarURL], merge: true)
                    if case .signedIn(var currentProfile) = self.authState, currentProfile.id == uid {
                        currentProfile.avatarURL = avatarURL
                        self.authState = .signedIn(profile: currentProfile)
                    }
                } catch {
                    print("Avatar upload failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Sign out

    func signOut() {
        try? auth.signOut()
        // Update state immediately so the UI responds without waiting for the listener.
        authState = .signedOut
    }
}

enum ProfileSaveError: LocalizedError {
    case invalidState

    var errorDescription: String? {
        switch self {
        case .invalidState:
            return "User is not in the needsUsername state."
        }
    }
}
