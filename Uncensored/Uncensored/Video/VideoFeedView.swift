//
//  VideoFeedView.swift
//  Uncensored
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

/// TikTok-style vertical full-screen video feed.
/// Loads videos from Firestore with infinite scroll pagination.
struct VideoFeedView: View {

    @StateObject private var viewModel = VideoFeedViewModel()
    @State private var currentIndex = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.videos.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                feedPager
            }

            if viewModel.isLoading && viewModel.videos.isEmpty {
                ProgressView()
                    .tint(.white)
            }
        }
        .task { await viewModel.loadInitial() }
    }

    // MARK: - Feed pager

    private var feedPager: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                videoPage(video: video, index: index)
                    .tag(index)
                    .onAppear {
                        if index == viewModel.videos.count - 2 {
                            Task { await viewModel.loadMore() }
                        }
                    }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }

    // MARK: - Single video page

    private func videoPage(video: VideoModel, index: Int) -> some View {
        ZStack(alignment: .bottom) {
            // Background colour until video loads
            Color.black.ignoresSafeArea()

            // Video player
            if let url = URL(string: video.videoURL) {
                VideoPlayerView(url: url, isActive: currentIndex == index)
            } else {
                placeholderBackground(index: index)
            }

            // Gradient overlay for readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Bottom content row
            HStack(alignment: .bottom, spacing: 0) {
                // Caption + author info
                videoInfo(video: video)
                Spacer(minLength: 0)
                // Right-side interaction panel
                VideoInteractionView(
                    video: video,
                    onLike: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            viewModel.toggleLike(for: video)
                        }
                    },
                    onComment: { },
                    onShare: { },
                    onFollow: { },
                    isLiked: viewModel.likeBinding(for: video)
                )
            }
            .padding(.horizontal, 12)
        }
    }

    private func videoInfo(video: VideoModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("@\(video.authorId)")
                .font(.headline.bold())
                .foregroundColor(.white)
                .shadow(radius: 2)

            if !video.caption.isEmpty {
                Text(video.caption)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .shadow(radius: 2)
            }
        }
        .padding(.leading, 4)
        .padding(.bottom, 80)
    }

    private func placeholderBackground(index: Int) -> some View {
        Color(hue: Double(index % 10) / 10.0, saturation: 0.5, brightness: 0.25)
            .ignoresSafeArea()
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.4))
            )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 56))
                .foregroundColor(.gray)
            Text("No videos yet")
                .font(.title3.bold())
                .foregroundColor(.white)
            Text("Be the first to post!")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class VideoFeedViewModel: ObservableObject {

    @Published var videos: [VideoModel] = []
    @Published var isLoading = false

    private var likedVideoIDs: Set<String> = []
    private var lastDocument: QueryDocumentSnapshot?
    private let pageSize = 10
    private let firestore = FirebaseManager.shared.firestore
    private var hasMore = true

    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        lastDocument = nil
        hasMore = true
        videos = []
        await fetchPage()
        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        await fetchPage()
        isLoading = false
    }

    func toggleLike(for video: VideoModel) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if likedVideoIDs.contains(video.id) {
            likedVideoIDs.remove(video.id)
            updateLikeCount(videoId: video.id, delta: -1)
        } else {
            likedVideoIDs.insert(video.id)
            updateLikeCount(videoId: video.id, delta: 1)
        }
        // Persist like to Firestore
        let likeRef = firestore
            .collection("users").document(uid)
            .collection("likes").document(video.id)
        if likedVideoIDs.contains(video.id) {
            likeRef.setData(["videoId": video.id, "likedAt": Date()])
        } else {
            likeRef.delete()
        }
    }

    func likeBinding(for video: VideoModel) -> Binding<Bool> {
        Binding(
            get: { self.likedVideoIDs.contains(video.id) },
            set: { newValue in
                let isCurrentlyLiked = self.likedVideoIDs.contains(video.id)
                if newValue != isCurrentlyLiked {
                    self.toggleLike(for: video)
                }
            }
        )
    }

    private func updateLikeCount(videoId: String, delta: Int) {
        if let index = videos.firstIndex(where: { $0.id == videoId }) {
            videos[index].likesCount = max(0, videos[index].likesCount + delta)
        }
    }

    private func fetchPage() async {
        do {
            var query = firestore
                .collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
            if let last = lastDocument {
                query = query.start(afterDocument: last)
            }
            let snapshot = try await query.getDocuments()
            let decoded = snapshot.documents.compactMap { try? $0.data(as: VideoModel.self) }
            videos.append(contentsOf: decoded)
            lastDocument = snapshot.documents.last
            hasMore = decoded.count == pageSize
        } catch {
            // Silently fail for now; could surface an error state
        }
    }
}

#Preview {
    VideoFeedView()
}
