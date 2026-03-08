//
//  FollowingListView.swift
//  Uncensored
//

import SwiftUI
import FirebaseFirestore

/// Shows the list of accounts a given user follows.
struct FollowingListView: View {

    let userId: String
    @State private var following: [UserProfile] = []
    @State private var isLoading = false

    private let firestore = FirebaseManager.shared.firestore

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if following.isEmpty {
                emptyState
            } else {
                List(following) { user in
                    userRow(user)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFollowing() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Not following anyone yet")
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

    private func loadFollowing() async {
        isLoading = true
        do {
            // Query follows where follower == userId
            let snapshot = try await firestore
                .collection("follows")
                .whereField("follower", isEqualTo: userId)
                .getDocuments()
            let followingIds = snapshot.documents.compactMap { $0.data()["following"] as? String }
            var profiles: [UserProfile] = []
            for uid in followingIds {
                if let doc = try? await firestore.collection("users").document(uid).getDocument(),
                   let profile = try? doc.data(as: UserProfile.self) {
                    profiles.append(profile)
                }
            }
            following = profiles
        } catch {
            // Silently fail
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        FollowingListView(userId: "preview")
    }
}
