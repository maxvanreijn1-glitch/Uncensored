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
enum AuthState {
    case loading
    case signedOut
    case needsUsername(uid: String)
    case signedIn(profile: UserProfile)
}

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var authState: AuthState = .loading

    private let auth = FirebaseManager.shared.auth
    private let firestore = FirebaseManager.shared.firestore
    private let storage = FirebaseManager.shared.storage
    // nonisolated(unsafe) lets deinit (which is always nonisolated) safely access
    // this handle under the SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor build setting.
    // nonisolated(unsafe) so that deinit can safely remove the listener
    // without crossing actor isolation boundaries.
    nonisolated(unsafe) private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        listenToAuthState()
    }

    deinit {
        if let handle = authStateHandle {
            // Use Auth.auth() directly so deinit doesn't need to hop to the main actor.
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth state listener

    private func listenToAuthState() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
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

        // Transition to signed-in state right away — don't wait for the avatar upload.
        let snapshot = try await docRef.getDocument()
        if let profile = try? snapshot.data(as: UserProfile.self), !profile.username.isEmpty {
            authState = .signedIn(profile: profile)
        } else {
            var stub = UserProfile.stub(uid: uid)
            stub.username = username
            stub.displayName = displayName
            stub.bio = bio
            authState = .signedIn(profile: stub)
        }

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
                    // Non-critical: avatar upload failed silently.
                }
            }
        }
    }

    enum ProfileSaveError: LocalizedError {
        case invalidState
        var errorDescription: String? {
            switch self {
            case .invalidState:
                return "Profile setup is unavailable right now. Please try again."
            }
        }
    }

    // MARK: - Legacy username-only save (kept for backward compatibility)

    func saveUsername(_ username: String) async throws {
        try await saveProfile(username: username, displayName: "", bio: "", avatarData: nil)
    }

    // MARK: - Convenience accessors

    /// The username of the currently signed-in user, or empty string if not available.
    var currentUsername: String {
        if case .signedIn(let profile) = authState, !profile.username.isEmpty {
            return profile.username
        }
        return ""
    }

    /// The UID of the currently signed-in user, or empty string if not available.
    var currentUserId: String {
        if case .signedIn(let profile) = authState {
            return profile.id
        }
        return auth.currentUser?.uid ?? ""
    }

    /// The current user's profile, if signed in.
    var currentProfile: UserProfile? {
        if case .signedIn(let profile) = authState { return profile }
        return nil
    }

    // MARK: - Sign out

    func signOut() {
        try? auth.signOut()
    }

    // MARK: - Update profile (for settings)

    func updateProfile(displayName: String, bio: String, isPrivate: Bool, avatarData: Data?) async throws {
        guard case .signedIn(let profile) = authState else { return }
        let uid = profile.id
        let docRef = firestore.collection("users").document(uid)
        let updateData: [String: Any] = [
            "displayName": displayName,
            "bio": bio,
            "isPrivate": isPrivate,
        ]
        try await docRef.setData(updateData, merge: true)
        // Patch in-memory profile
        if case .signedIn(var current) = authState {
            current.displayName = displayName
            current.bio = bio
            current.isPrivate = isPrivate
            authState = .signedIn(profile: current)
        }
        // Upload avatar if provided
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
                    if case .signedIn(var current) = self.authState, current.id == uid {
                        current.avatarURL = avatarURL
                        self.authState = .signedIn(profile: current)
                    }
                } catch {
                    // Non-critical
                }
            }
        }
    }
}
