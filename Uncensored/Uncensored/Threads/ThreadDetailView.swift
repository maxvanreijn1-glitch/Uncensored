//
//  ThreadDetailView.swift
//  Uncensored
//

import SwiftUI

/// Shows a single thread and its replies.
struct ThreadDetailView: View {

    let thread: ThreadModel

    // TODO: Fetch real replies from Firestore `threads/{id}/replies`.
    @State private var replies: [ThreadReply] = Self.placeholderReplies
    @State private var isLikedThread = false

    var body: some View {
        List {
            // Original thread
            Section {
                ThreadRowView(
                    thread: thread,
                    isLiked: $isLikedThread,
                    onLike: { isLikedThread.toggle() }
                )
            }

            // Replies
            Section("Replies") {
                if replies.isEmpty {
                    Text("No replies yet. Be the first!")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(replies) { reply in
                        replyRow(reply)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func replyRow(_ reply: ThreadReply) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(Text(reply.authorUsername.prefix(1).uppercased()).font(.caption))
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(reply.authorUsername)").font(.subheadline.bold())
                Text(reply.body).font(.body)
                Label("\(reply.likesCount)", systemImage: "heart")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private static var placeholderReplies: [ThreadReply] {
        (1...3).map { i in
            ThreadReply(
                id: UUID().uuidString,
                authorId: "user\(i)",
                authorUsername: "replier\(i)",
                body: "This is placeholder reply #\(i).",
                likesCount: i * 3,
                createdAt: Date().addingTimeInterval(TimeInterval(-i * 120))
            )
        }
    }
}

#Preview {
    NavigationStack {
        ThreadDetailView(thread: ThreadModel(
            id: "preview",
            authorId: "uid",
            authorUsername: "previewuser",
            body: "This is a preview thread.",
            likesCount: 42,
            repliesCount: 3,
            createdAt: Date()
        ))
    }
}
