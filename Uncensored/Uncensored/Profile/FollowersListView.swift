//
//  FollowersListView.swift
//  Uncensored
//

import SwiftUI
import FirebaseFirestore

/// Shows the list of followers for a given user.
struct FollowersListView: View {

    let userId: String
    @State private var followers: [UserProfile] = []
    @State private var isLoading = false

    private let firestore = FirebaseManager.shared.firestore

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if followers.isEmpty {
                emptyState
            } else {
                List(followers) { user in
                    userRow(user)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Followers")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFollowers() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No followers yet")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func userRow(_ user: UserProfile) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(user.username.prefix(1).uppercased())
                        .font(.headline)
                )
            VStack(alignment: .leading, spacing: 2) {
                if !user.displayName.isEmpty {
                    Text(user.displayName)
                        .font(.subheadline.bold())
                }
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func loadFollowers() async {
        isLoading = true
        do {
            // Query follows where following == userId
            let snapshot = try await firestore
                .collection("follows")
                .whereField("following", isEqualTo: userId)
                .getDocuments()
            let followerIds = snapshot.documents.compactMap { $0.data()["follower"] as? String }
            var profiles: [UserProfile] = []
            for uid in followerIds {
                if let doc = try? await firestore.collection("users").document(uid).getDocument(),
                   let profile = try? doc.data(as: UserProfile.self) {
                    profiles.append(profile)
                }
            }
            followers = profiles
        } catch {
            // Silently fail
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        FollowersListView(userId: "preview")
    }
}
