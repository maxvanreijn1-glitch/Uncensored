//
//  ProfileView.swift
//  Uncensored
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Complete TikTok-style user profile screen with videos, threads, and likes tabs.
struct ProfileView: View {

    let profile: UserProfile
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var selectedTab: ProfileTab = .videos
    @State private var showEditProfile = false

    // Placeholder grid data (replace with real Firestore fetch)
    private let placeholderVideos = Array(0..<9)

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    enum ProfileTab: String, CaseIterable {
        case videos = "Videos"
        case threads = "Threads"
        case likes = "Likes"

        var icon: String {
            switch self {
            case .videos:  return "play.rectangle.fill"
            case .threads: return "text.bubble"
            case .likes:   return "heart"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader
                statsRow
                actionButtons
                Divider().padding(.vertical, 8)
                tabBar
                tabContent
                signOutButton
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditProfile = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfilePlaceholderView(profile: profile)
                .environmentObject(authVM)
        }
    }

    // MARK: - Subviews

    private var profileHeader: some View {
        VStack(spacing: 10) {
            // Avatar
            if let avatarURLString = profile.avatarURL,
               let avatarURL = URL(string: avatarURLString) {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarPlaceholder
                    }
                }
                .frame(width: 88, height: 88)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }

            // Names
            if !profile.displayName.isEmpty {
                Text(profile.displayName)
                    .font(.title3.bold())
            }
            Text("@\(profile.username.isEmpty ? "unknown" : profile.username)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.3))
            .frame(width: 88, height: 88)
            .overlay(
                Text(profile.username.isEmpty ? "?" : profile.username.prefix(1).uppercased())
                    .font(.largeTitle.bold())
            )
    }

    private var statsRow: some View {
        HStack(spacing: 40) {
            statColumn(value: profile.followingCount, label: "Following")
            statColumn(value: profile.followersCount, label: "Followers")
            statColumn(value: profile.videosCount, label: "Posts")
        }
        .padding(.vertical, 12)
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

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Edit profile") { showEditProfile = true }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary, lineWidth: 1)
                )
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation { selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Rectangle()
                                .fill(Color.primary)
                                .frame(height: 1.5)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .videos:
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(placeholderVideos, id: \.self) { i in
                    Color(hue: Double(i) / Double(max(placeholderVideos.count, 1)),
                          saturation: 0.5, brightness: 0.5)
                        .aspectRatio(9/16, contentMode: .fill)
                        .overlay(
                            Image(systemName: "play.fill")
                                .foregroundColor(.white.opacity(0.6))
                        )
                        .clipped()
                }
            }
            .padding(.top, 2)

        case .threads:
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    threadPlaceholderRow(index: i)
                    Divider().padding(.leading, 56)
                }
            }

        case .likes:
            emptyTabView(icon: "heart", message: "No liked videos yet")
        }
    }

    private func threadPlaceholderRow(index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            avatarPlaceholder
                .frame(width: 36, height: 36)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(profile.username)")
                    .font(.subheadline.bold())
                Text("Placeholder thread #\(index + 1)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func emptyTabView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            authVM.signOut()
        } label: {
            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .padding(.top, 24)
        .padding(.bottom, 40)
    }
}

// MARK: - Edit Profile placeholder sheet

private struct EditProfilePlaceholderView: View {
    let profile: UserProfile
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.pencil")
                    .font(.system(size: 56))
                    .foregroundColor(.accentColor)
                Text("Edit Profile")
                    .font(.title2.bold())
                Text("Full profile editing coming soon.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
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
