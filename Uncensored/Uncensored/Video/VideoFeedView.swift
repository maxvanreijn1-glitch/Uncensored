//
//  VideoFeedView.swift
//  Uncensored
//

import SwiftUI
import Combine
import UIKit

/// TikTok-style vertical full-screen video feed.
/// Loads videos from Firestore with infinite scroll pagination.
struct VideoFeedView: View {

    @StateObject private var viewModel = VideoFeedViewModel()
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var currentIndex = 0
    @State private var showCommentsForVideo: VideoModel?
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var videoToDelete: VideoModel?
    @State private var showDeleteConfirm = false

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
        .sheet(item: $showCommentsForVideo) { video in
            let binding = Binding<Int>(
                get: {
                    viewModel.videos.first(where: { $0.id == video.id })?.commentsCount ?? video.commentsCount
                },
                set: { newVal in
                    if let idx = viewModel.videos.firstIndex(where: { $0.id == video.id }) {
                        viewModel.videos[idx].commentsCount = newVal
                    }
                }
            )
            CommentsView(videoId: video.id, commentsCount: binding)
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .confirmationDialog("Delete this video?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let video = videoToDelete {
                    Task { await viewModel.deleteVideo(video) }
                }
            }
        }
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
                    onComment: {
                        showCommentsForVideo = video
                    },
                    onShare: {
                        let text = "\(video.caption.isEmpty ? "Check out this video" : video.caption)\n\(video.videoURL)"
                        shareItems = [text]
                        showShareSheet = true
                    },
                    onFollow: { },
                    isLiked: viewModel.likeBinding(for: video),
                    isOwnContent: video.authorId == authVM.currentUserId,
                    onDelete: {
                        videoToDelete = video
                        showDeleteConfirm = true
                    }
                )
            }
            .padding(.horizontal, 12)
        }
    }

    private func videoInfo(video: VideoModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("@\(video.authorUsername.isEmpty ? video.authorId : video.authorUsername)")
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

// MARK: - ShareSheet (UIActivityViewController wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    VideoFeedView()
        .environmentObject(AuthViewModel())
}

