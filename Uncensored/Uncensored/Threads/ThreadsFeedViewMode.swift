//
//  ThreadsFeedViewMode.swift
//  Uncensored
//

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// ViewModel for the Twitter/Threads-style text feed.
/// Handles Firestore pagination and like state.
@MainActor
final class ThreadsFeedViewModel: ObservableObject {

    @Published var threads: [ThreadModel] = []
    @Published var isLoading = false

    private var likedThreadIDs: Set<String> = []
    private var lastDocument: QueryDocumentSnapshot?
    private let pageSize = 20
    private let firestore = FirebaseManager.shared.firestore
    private var hasMore = true

    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        lastDocument = nil
        hasMore = true
        threads = []
        await fetchPage()
        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        await fetchPage()
        isLoading = false
    }

    func toggleLike(for thread: ThreadModel) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if likedThreadIDs.contains(thread.id) {
            likedThreadIDs.remove(thread.id)
            updateLikeCount(threadId: thread.id, delta: -1)
        } else {
            likedThreadIDs.insert(thread.id)
            updateLikeCount(threadId: thread.id, delta: 1)
        }
        let likeRef = firestore
            .collection("users").document(uid)
            .collection("threadLikes").document(thread.id)
        if likedThreadIDs.contains(thread.id) {
            likeRef.setData(["threadId": thread.id, "likedAt": Date()])
        } else {
            likeRef.delete()
        }
    }

    func likeBinding(for thread: ThreadModel) -> Binding<Bool> {
        Binding(
            get: { self.likedThreadIDs.contains(thread.id) },
            set: { newValue in
                let isCurrentlyLiked = self.likedThreadIDs.contains(thread.id)
                if newValue != isCurrentlyLiked {
                    self.toggleLike(for: thread)
                }
            }
        )
    }

    private func updateLikeCount(threadId: String, delta: Int) {
        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index].likesCount = max(0, threads[index].likesCount + delta)
        }
    }

    private func fetchPage() async {
        do {
            var query = firestore
                .collection("threads")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
            if let last = lastDocument {
                query = query.start(afterDocument: last)
            }
            let snapshot = try await query.getDocuments()
            let decoded = snapshot.documents.compactMap { try? $0.data(as: ThreadModel.self) }
            threads.append(contentsOf: decoded)
            lastDocument = snapshot.documents.last
            hasMore = decoded.count == pageSize
        } catch {
            // Silently fail; could surface error state
        }
    }
}
