//
//  CommentsView.swift
//  Uncensored
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Displays and manages comments for a video.
struct CommentsView: View {

    let videoId: String
    @Binding var commentsCount: Int
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var comments: [Comment] = []
    @State private var isLoading = false
    @State private var commentText = ""
    @State private var isPosting = false
    @State private var errorMessage: String?

    private let firestore = FirebaseManager.shared.firestore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading && comments.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    emptyState
                } else {
                    commentsList
                }

                Divider()
                composerBar
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await loadComments() }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No comments yet")
                .font(.headline)
            Text("Be the first to comment!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var commentsList: some View {
        List {
            ForEach(comments) { comment in
                commentRow(comment)
                    .swipeActions(edge: .trailing) {
                        if comment.authorId == Auth.auth().currentUser?.uid {
                            Button(role: .destructive) {
                                Task { await deleteComment(comment) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private func commentRow(_ comment: Comment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(comment.authorUsername.prefix(1).uppercased())
                        .font(.subheadline.bold())
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@\(comment.authorUsername)")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(comment.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(comment.body)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            TextField("Add a comment…", text: $commentText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(4)

            Button {
                Task { await postComment() }
            } label: {
                if isPosting {
                    ProgressView()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                }
            }
            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
        }
        .padding()
    }

    // MARK: - Actions

    private func loadComments() async {
        isLoading = true
        do {
            let snapshot = try await firestore
                .collection("videos").document(videoId)
                .collection("comments")
                .order(by: "createdAt", descending: false)
                .getDocuments()
            comments = snapshot.documents.compactMap { try? $0.data(as: Comment.self) }
        } catch {
            // Silently fail
        }
        isLoading = false
    }

    private func postComment() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let body = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let username = authVM.currentUsername.isEmpty ? "anonymous" : authVM.currentUsername
        isPosting = true
        let commentId = UUID().uuidString
        let comment = Comment(
            id: commentId,
            authorId: uid,
            authorUsername: username,
            body: body,
            likesCount: 0,
            createdAt: Date()
        )
        do {
            let data = try Firestore.Encoder().encode(comment)
            try await firestore
                .collection("videos").document(videoId)
                .collection("comments").document(commentId)
                .setData(data)
            // Update comments count
            try await firestore.collection("videos").document(videoId)
                .updateData(["commentsCount": FieldValue.increment(Int64(1))])
            commentText = ""
            comments.append(comment)
            commentsCount += 1
        } catch {
            errorMessage = error.localizedDescription
        }
        isPosting = false
    }

    private func deleteComment(_ comment: Comment) async {
        do {
            try await firestore
                .collection("videos").document(videoId)
                .collection("comments").document(comment.id)
                .delete()
            try await firestore.collection("videos").document(videoId)
                .updateData(["commentsCount": FieldValue.increment(Int64(-1))])
            comments.removeAll { $0.id == comment.id }
            commentsCount = max(0, commentsCount - 1)
        } catch {
            // Silently fail
        }
    }
}

#Preview {
    CommentsView(videoId: "preview", commentsCount: .constant(5))
        .environmentObject(AuthViewModel())
}
