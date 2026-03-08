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
        await loadLikedIDs()
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
        let wasLiked = likedThreadIDs.contains(thread.id)
        if wasLiked {
            likedThreadIDs.remove(thread.id)
            updateLikeCount(threadId: thread.id, delta: -1)
        } else {
            likedThreadIDs.insert(thread.id)
            updateLikeCount(threadId: thread.id, delta: 1)
        }
        // Persist like to threads/{threadId}/likes/{uid} per spec
        let likeRef = firestore
            .collection("threads").document(thread.id)
            .collection("likes").document(uid)
        // Also track in user's liked list
        let userLikeRef = firestore
            .collection("users").document(uid)
            .collection("threadLikes").document(thread.id)
        let threadRef = firestore.collection("threads").document(thread.id)
        if !wasLiked {
            likeRef.setData(["uid": uid, "likedAt": FieldValue.serverTimestamp()])
            userLikeRef.setData(["threadId": thread.id, "likedAt": FieldValue.serverTimestamp()])
            threadRef.updateData(["likesCount": FieldValue.increment(Int64(1))])
        } else {
            likeRef.delete()
            userLikeRef.delete()
            threadRef.updateData(["likesCount": FieldValue.increment(Int64(-1))])
        }
    }

    func deleteThread(_ thread: ThreadModel) async {
        guard let uid = Auth.auth().currentUser?.uid, uid == thread.authorId else { return }
        do {
            try await firestore.collection("threads").document(thread.id).delete()
            threads.removeAll { $0.id == thread.id }
        } catch {
            // Handle error silently
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

    private func loadLikedIDs() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snapshot = try await firestore
                .collection("users").document(uid)
                .collection("threadLikes")
                .getDocuments()
            likedThreadIDs = Set(snapshot.documents.map { $0.documentID })
        } catch {
            // Not critical
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
