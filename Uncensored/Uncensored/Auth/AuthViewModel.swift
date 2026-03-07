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
    private var authStateHandle: AuthStateDidChangeListenerHandle?

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
        guard case .needsUsername(let uid) = authState else { return }

        // Upload avatar first if provided
        var uploadedAvatarURL: String? = nil
        if let data = avatarData {
            let storageRef = storage.reference().child("avatars/\(uid).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await storageRef.putDataAsync(data, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()
            uploadedAvatarURL = downloadURL.absoluteString
        }

        // Write all profile fields to Firestore
        let docRef = firestore.collection("users").document(uid)
        var updateData: [String: Any] = [
            "username": username,
            "displayName": displayName,
            "bio": bio,
        ]
        if let avatarURL = uploadedAvatarURL {
            updateData["avatarURL"] = avatarURL
        }
        try await docRef.updateData(updateData)

        let snapshot = try await docRef.getDocument()
        if let profile = try? snapshot.data(as: UserProfile.self) {
            authState = .signedIn(profile: profile)
        } else {
            var stub = UserProfile.stub(uid: uid)
            stub.username = username
            stub.displayName = displayName
            stub.bio = bio
            stub.avatarURL = uploadedAvatarURL
            authState = .signedIn(profile: stub)
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
