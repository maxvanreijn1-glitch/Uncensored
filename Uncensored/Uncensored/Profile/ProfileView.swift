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
    @State private var showSettings = false

    // Real data
    @State private var videos: [VideoModel] = []
    @State private var threads: [ThreadModel] = []
    @State private var likedVideos: [VideoModel] = []
    @State private var isLoadingContent = false
    @State private var followersCount: Int
    @State private var followingCount: Int
    @State private var videosCount: Int

    // Follow state
    @State private var isFollowing = false
    @State private var isTogglingFollow = false

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var threadToDelete: ThreadModel?
    @State private var showDeleteThreadConfirm = false

    private let firestore = FirebaseManager.shared.firestore

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var isOwnProfile: Bool {
        profile.id == authVM.currentUserId
    }

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

    init(profile: UserProfile) {
        self.profile = profile
        _followersCount = State(initialValue: profile.followersCount)
        _followingCount = State(initialValue: profile.followingCount)
        _videosCount = State(initialValue: profile.videosCount)
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
                if isOwnProfile {
                    signOutButton
                }
            }
        }
        .navigationTitle(isOwnProfile ? "Profile" : "@\(profile.username)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnProfile {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        shareItems = ["Check out @\(profile.username) on Uncensored!"]
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(profile: profile)
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .confirmationDialog("Delete Thread?", isPresented: $showDeleteThreadConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let thread = threadToDelete {
                    Task { await deleteThread(thread) }
                }
            }
        }
        .task {
            await loadContent()
            if !isOwnProfile {
                await checkFollowStatus()
            }
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
        avatarView(size: 88, font: .largeTitle.bold())
    }

    private func avatarView(size: CGFloat, font: Font) -> some View {
        Circle()
            .fill(Color.accentColor.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Text(profile.username.isEmpty ? "?" : profile.username.prefix(1).uppercased())
                    .font(font)
            )
    }

    private var statsRow: some View {
        HStack(spacing: 40) {
            NavigationLink(destination: FollowingListView(userId: profile.id)) {
                statColumn(value: followingCount, label: "Following")
            }
            .foregroundColor(.primary)

            NavigationLink(destination: FollowersListView(userId: profile.id)) {
                statColumn(value: followersCount, label: "Followers")
            }
            .foregroundColor(.primary)

            statColumn(value: videosCount, label: "Posts")
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
            if isOwnProfile {
                Button("Edit profile") { showEditProfile = true }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, lineWidth: 1)
                    )
                    .foregroundColor(.primary)
            } else {
                Button {
                    Task { await toggleFollow() }
                } label: {
                    if isTogglingFollow {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 36)
                    } else {
                        Text(isFollowing ? "Unfollow" : "Follow")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(isFollowing ? Color.secondary.opacity(0.2) : Color.accentColor)
                            .foregroundColor(isFollowing ? .primary : .white)
                            .cornerRadius(8)
                    }
                }
                .disabled(isTogglingFollow)
            }
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
        if isLoadingContent {
            ProgressView()
                .padding(.top, 40)
        } else {
            switch selectedTab {
            case .videos:
                if videos.isEmpty {
                    emptyTabView(icon: "play.rectangle", message: "No videos yet")
                } else {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(videos) { video in
                            videoThumbnail(video)
                        }
                    }
                    .padding(.top, 2)
                }

            case .threads:
                if threads.isEmpty {
                    emptyTabView(icon: "text.bubble", message: "No threads yet")
                } else {
                    VStack(spacing: 0) {
                        ForEach(threads) { thread in
                            threadRow(thread)
                            Divider().padding(.leading, 56)
                        }
                    }
                }

            case .likes:
                if likedVideos.isEmpty {
                    emptyTabView(icon: "heart", message: "No liked videos yet")
                } else {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(likedVideos) { video in
                            videoThumbnail(video)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func videoThumbnail(_ video: VideoModel) -> some View {
        ZStack {
            if let thumbnailURL = video.thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: videoPlaceholderColor(video)
                    }
                }
            } else {
                videoPlaceholderColor(video)
            }
            Image(systemName: "play.fill")
                .foregroundColor(.white.opacity(0.7))
                .font(.title3)
        }
        .aspectRatio(9/16, contentMode: .fill)
        .clipped()
        .contextMenu {
            if isOwnProfile {
                Button(role: .destructive) {
                    Task { await deleteVideo(video) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func videoPlaceholderColor(_ video: VideoModel) -> some View {
        Color(hue: Double(video.id.hashValue % 10) / 10.0, saturation: 0.5, brightness: 0.4)
    }

    private func threadRow(_ thread: ThreadModel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            avatarView(size: 36, font: .subheadline.bold())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@\(thread.authorUsername)")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(thread.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if isOwnProfile {
                        Button {
                            threadToDelete = thread
                            showDeleteThreadConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(thread.body)
                    .font(.body)
                    .foregroundColor(.secondary)
                HStack(spacing: 16) {
                    Label("\(thread.repliesCount)", systemImage: "bubble.right")
                        .font(.caption).foregroundColor(.secondary)
                    Label("\(thread.likesCount)", systemImage: "heart")
                        .font(.caption).foregroundColor(.secondary)
                }
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

    // MARK: - Data loading

    private func loadContent() async {
        isLoadingContent = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadVideos() }
            group.addTask { await loadThreads() }
            group.addTask { await loadLikedVideos() }
        }
        isLoadingContent = false
    }

    private func loadVideos() async {
        do {
            let snapshot = try await firestore
                .collection("videos")
                .whereField("authorId", isEqualTo: profile.id)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            let decoded = snapshot.documents.compactMap { try? $0.data(as: VideoModel.self) }
            await MainActor.run {
                videos = decoded
                videosCount = decoded.count
            }
        } catch {
            // Silently fail
        }
    }

    private func loadThreads() async {
        do {
            let snapshot = try await firestore
                .collection("threads")
                .whereField("authorId", isEqualTo: profile.id)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            let decoded = snapshot.documents.compactMap { try? $0.data(as: ThreadModel.self) }
            await MainActor.run { threads = decoded }
        } catch {
            // Silently fail
        }
    }

    private func loadLikedVideos() async {
        do {
            let likeSnapshot = try await firestore
                .collection("users").document(profile.id)
                .collection("videoLikes")
                .getDocuments()
            let videoIds = likeSnapshot.documents.map { $0.documentID }
            var result: [VideoModel] = []
            for videoId in videoIds {
                if let doc = try? await firestore.collection("videos").document(videoId).getDocument(),
                   let video = try? doc.data(as: VideoModel.self) {
                    result.append(video)
                }
            }
            await MainActor.run { likedVideos = result }
        } catch {
            // Silently fail
        }
    }

    // MARK: - Follow / Unfollow

    private func checkFollowStatus() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let followId = "\(uid)_\(profile.id)"
            let doc = try await firestore.collection("follows").document(followId).getDocument()
            await MainActor.run { isFollowing = doc.exists }
        } catch {
            // Silently fail
        }
    }

    private func toggleFollow() async {
        guard let uid = Auth.auth().currentUser?.uid, !isOwnProfile else { return }
        isTogglingFollow = true
        let followId = "\(uid)_\(profile.id)"
        let followRef = firestore.collection("follows").document(followId)
        do {
            if isFollowing {
                try await followRef.delete()
                // Decrement counts
                try await firestore.collection("users").document(profile.id)
                    .updateData(["followersCount": FieldValue.increment(Int64(-1))])
                try await firestore.collection("users").document(uid)
                    .updateData(["followingCount": FieldValue.increment(Int64(-1))])
                isFollowing = false
                followersCount = max(0, followersCount - 1)
            } else {
                let followData: [String: Any] = [
                    "follower": uid,
                    "following": profile.id,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                try await followRef.setData(followData)
                // Increment counts
                try await firestore.collection("users").document(profile.id)
                    .updateData(["followersCount": FieldValue.increment(Int64(1))])
                try await firestore.collection("users").document(uid)
                    .updateData(["followingCount": FieldValue.increment(Int64(1))])
                isFollowing = true
                followersCount += 1
            }
        } catch {
            // Silently fail
        }
        isTogglingFollow = false
    }

    // MARK: - Delete

    private func deleteVideo(_ video: VideoModel) async {
        do {
            try await firestore.collection("videos").document(video.id).delete()
            videos.removeAll { $0.id == video.id }
            videosCount = max(0, videosCount - 1)
        } catch {
            // Silently fail
        }
    }

    private func deleteThread(_ thread: ThreadModel) async {
        do {
            try await firestore.collection("threads").document(thread.id).delete()
            threads.removeAll { $0.id == thread.id }
        } catch {
            // Silently fail
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
            isPrivate: false,
            createdAt: Date()
        ))
    }
    .environmentObject(AuthViewModel())
}

