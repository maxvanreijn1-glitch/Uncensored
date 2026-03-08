//
//  VideoFeedViewMode.swift
//  Uncensored
//

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// ViewModel for the TikTok-style vertical video feed.
/// Handles Firestore pagination, like state, and video data.
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
