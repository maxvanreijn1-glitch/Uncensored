//
//  RepliesView.swift
//  Uncensored
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Displays and manages replies for a thread.
struct RepliesView: View {

    let threadId: String
    @Binding var repliesCount: Int
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var replies: [ThreadReply] = []
    @State private var isLoading = false
    @State private var replyText = ""
    @State private var isPosting = false
    @State private var errorMessage: String?

    private let firestore = FirebaseManager.shared.firestore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading && replies.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if replies.isEmpty {
                    emptyState
                } else {
                    repliesList
                }

                Divider()
                composerBar
            }
            .navigationTitle("Replies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await loadReplies() }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No replies yet")
                .font(.headline)
            Text("Be the first to reply!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var repliesList: some View {
        List {
            ForEach(replies) { reply in
                replyRow(reply)
                    .swipeActions(edge: .trailing) {
                        if reply.authorId == Auth.auth().currentUser?.uid {
                            Button(role: .destructive) {
                                Task { await deleteReply(reply) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private func replyRow(_ reply: ThreadReply) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(reply.authorUsername.prefix(1).uppercased())
                        .font(.subheadline.bold())
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@\(reply.authorUsername)")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(reply.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(reply.body)
                    .font(.body)
                Label("\(reply.likesCount)", systemImage: "heart")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            TextField("Add a reply…", text: $replyText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button {
                Task { await postReply() }
            } label: {
                if isPosting {
                    ProgressView()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                }
            }
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
        }
        .padding()
    }

    // MARK: - Actions

    private func loadReplies() async {
        isLoading = true
        do {
            let snapshot = try await firestore
                .collection("threads").document(threadId)
                .collection("replies")
                .order(by: "createdAt", descending: false)
                .getDocuments()
            replies = snapshot.documents.compactMap { try? $0.data(as: ThreadReply.self) }
        } catch {
            // Silently fail
        }
        isLoading = false
    }

    private func postReply() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let body = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let username = authVM.currentUsername.isEmpty ? "anonymous" : authVM.currentUsername
        isPosting = true
        let replyId = UUID().uuidString
        let reply = ThreadReply(
            id: replyId,
            authorId: uid,
            authorUsername: username,
            body: body,
            likesCount: 0,
            createdAt: Date()
        )
        do {
            let data = try Firestore.Encoder().encode(reply)
            try await firestore
                .collection("threads").document(threadId)
                .collection("replies").document(replyId)
                .setData(data)
            // Update replies count
            firestore.collection("threads").document(threadId)
                .updateData(["repliesCount": FieldValue.increment(Int64(1))])
            replyText = ""
            replies.append(reply)
            repliesCount += 1
        } catch {
            errorMessage = error.localizedDescription
        }
        isPosting = false
    }

    private func deleteReply(_ reply: ThreadReply) async {
        do {
            try await firestore
                .collection("threads").document(threadId)
                .collection("replies").document(reply.id)
                .delete()
            firestore.collection("threads").document(threadId)
                .updateData(["repliesCount": FieldValue.increment(Int64(-1))])
            replies.removeAll { $0.id == reply.id }
            repliesCount = max(0, repliesCount - 1)
        } catch {
            // Silently fail
        }
    }
}

#Preview {
    RepliesView(threadId: "preview", repliesCount: .constant(3))
        .environmentObject(AuthViewModel())
}
