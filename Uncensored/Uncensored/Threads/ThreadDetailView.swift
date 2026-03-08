//
//  ThreadDetailView.swift
//  Uncensored
//

import SwiftUI

/// Shows a single thread with a button to view/add replies.
struct ThreadDetailView: View {

    let thread: ThreadModel
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var isLikedThread = false
    @State private var showReplies = false
    @State private var repliesCount: Int

    init(thread: ThreadModel) {
        self.thread = thread
        _repliesCount = State(initialValue: thread.repliesCount)
    }

    var body: some View {
        List {
            // Original thread
            Section {
                ThreadRowView(
                    thread: thread,
                    isLiked: $isLikedThread,
                    onLike: { isLikedThread.toggle() },
                    onShare: nil,
                    isOwnContent: false
                )
            }

            // Replies summary
            Section {
                Button {
                    showReplies = true
                } label: {
                    HStack {
                        Image(systemName: "bubble.right")
                        Text(repliesCount == 0 ? "Add a reply" : "\(repliesCount) \(repliesCount == 1 ? "reply" : "replies")")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReplies) {
            RepliesView(threadId: thread.id, repliesCount: $repliesCount)
                .environmentObject(authVM)
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
    .environmentObject(AuthViewModel())
}

