//
//  ThreadsFeedView.swift
//  Uncensored
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

/// Twitter/Threads-style text feed with real Firestore pagination.
struct ThreadsFeedView: View {

    @StateObject private var viewModel = ThreadsFeedViewModel()

    var body: some View {
        List {
            ForEach(viewModel.threads) { thread in
                NavigationLink(destination: ThreadDetailView(thread: thread)) {
                    ThreadRowView(
                        thread: thread,
                        isLiked: viewModel.likeBinding(for: thread),
                        onLike: { viewModel.toggleLike(for: thread) }
                    )
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .onAppear {
                    if thread.id == viewModel.threads.last?.id {
                        Task { await viewModel.loadMore() }
                    }
                }
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.loadInitial() }
        .task { await viewModel.loadInitial() }
        .overlay {
            if viewModel.threads.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No threads yet",
                    systemImage: "text.bubble",
                    description: Text("Be the first to post a thread!")
                )
            }
        }
    }
}

// MARK: - Thread Row

struct ThreadRowView: View {
    let thread: ThreadModel
    @Binding var isLiked: Bool
    var onLike: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(thread.authorUsername.prefix(1).uppercased())
                        .font(.headline)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("@\(thread.authorUsername)")
                        .font(.headline)
                    Spacer()
                    Text(thread.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(thread.body)
                    .font(.body)
                    .lineLimit(6)

                // Interaction row
                HStack(spacing: 24) {
                    Label("\(thread.repliesCount)", systemImage: "bubble.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            onLike()
                        }
                    } label: {
                        Label(
                            "\(thread.likesCount + (isLiked ? 1 : 0))",
                            systemImage: isLiked ? "heart.fill" : "heart"
                        )
                        .font(.caption)
                        .foregroundColor(isLiked ? .red : .secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        // TODO: Share sheet
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

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

#Preview {
    NavigationStack {
        ThreadsFeedView()
            .navigationTitle("Threads")
    }
}
