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
    // nonisolated(unsafe) so that deinit can safely remove the listener
    // without crossing actor isolation boundaries.
    nonisolated(unsafe) private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        listenToAuthState()
    }

    deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
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
                // First login – create a stub document
                let stub = UserProfile.stub(uid: uid)
                try? docRef.setData(from: stub)
                authState = .needsUsername(uid: uid)
            }
        } catch {
            // On error, default to needing username setup
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
            throw NSError(
                domain: "ProfileSetup",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid authentication state. Please sign out and try again."]
            )
        }

        let docRef = firestore.collection("users").document(uid)

        // Write text profile fields immediately.
        // Use setData(merge:) so the call succeeds whether the document exists or not.
        let profileFields: [String: Any] = [
            "username": username,
            "displayName": displayName,
            "bio": bio,
        ]
        try await docRef.setData(profileFields, merge: true)
        if let avatarURL = uploadedAvatarURL {
            updateData["avatarURL"] = avatarURL
        }
        try await docRef.setData(updateData, merge: true)

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
                    if case .signedIn(var currentProfile) = authState, currentProfile.id == uid {
                        currentProfile.avatarURL = avatarURL
                        authState = .signedIn(profile: currentProfile)
                    }
                } catch {
                    // Non-critical: avatar upload failed silently.
                }
            }
        }
    }

    // MARK: - Legacy username-only save (kept for backward compatibility)

    func saveUsername(_ username: String) async throws {
        try await saveProfile(username: username, displayName: "", bio: "", avatarData: nil)
    }

    // MARK: - Sign out

    func signOut() {
        try? auth.signOut()
    }
}
