//
//  ProfileView.swift
//  Uncensored
//

import SwiftUI

/// TikTok-style user profile screen.
struct ProfileView: View {

    let profile: UserProfile
    @EnvironmentObject private var authVM: AuthViewModel

    // TODO: Fetch real videos from Firestore.
    private let placeholderVideos = Array(0..<9)

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Avatar
                Circle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 88, height: 88)
                    .overlay(
                        Text(profile.username.isEmpty ? "?" : profile.username.prefix(1).uppercased())
                            .font(.largeTitle.bold())
                    )
                    .padding(.top, 24)

                // Username
                Text("@\(profile.username.isEmpty ? "unknown" : profile.username)")
                    .font(.title3.bold())
                    .padding(.top, 8)

                if !profile.bio.isEmpty {
                    Text(profile.bio)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 4)
                }

                // Stats row
                HStack(spacing: 40) {
                    statColumn(value: profile.followingCount, label: "Following")
                    statColumn(value: profile.followersCount, label: "Followers")
                    statColumn(value: profile.videosCount, label: "Likes")
                }
                .padding(.top, 16)

                Divider().padding(.vertical, 12)

                // Video grid
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(placeholderVideos, id: \.self) { i in
                        Color(hue: Double(i) / Double(placeholderVideos.count), saturation: 0.5, brightness: 0.5)
                            .aspectRatio(9/16, contentMode: .fill)
                            .overlay(Image(systemName: "play.fill").foregroundColor(.white.opacity(0.5)))
                    }
                }

                // Sign out
                Button(role: .destructive) {
                    authVM.signOut()
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(profile: UserProfile(
            id: "preview",
            username: "previewuser",
            displayName: "Preview User",
            bio: "Just a preview bio 🎉",
            avatarURL: nil,
            followersCount: 1200,
            followingCount: 340,
            videosCount: 24,
            createdAt: Date()
        ))
    }
    .environmentObject(AuthViewModel())
}
