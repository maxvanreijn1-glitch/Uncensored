//
//  ThreadsFeedView.swift
//  Uncensored
//

import SwiftUI

/// Twitter/Threads-style text feed.
struct ThreadsFeedView: View {

    // TODO: Fetch from Firestore `threads` collection.
    @State private var threads: [ThreadModel] = Self.placeholders

    var body: some View {
        List(threads) { thread in
            NavigationLink(destination: ThreadDetailView(thread: thread)) {
                ThreadRowView(thread: thread)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
        .refreshable {
            // TODO: Re-fetch threads from Firestore
        }
    }

    private static var placeholders: [ThreadModel] {
        (1...8).map { i in
            ThreadModel(
                id: UUID().uuidString,
                authorId: "user\(i)",
                authorUsername: "user\(i)",
                body: "This is placeholder thread #\(i). Replace with real Firestore data.",
                likesCount: i * 7,
                repliesCount: i * 2,
                createdAt: Date().addingTimeInterval(TimeInterval(-i * 600))
            )
        }
    }
}

// MARK: - Thread Row

struct ThreadRowView: View {
    let thread: ThreadModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(Text(thread.authorUsername.prefix(1).uppercased()).font(.headline))

            VStack(alignment: .leading, spacing: 6) {
                Text("@\(thread.authorUsername)")
                    .font(.headline)
                Text(thread.body)
                    .font(.body)
                    .lineLimit(4)
                HStack(spacing: 20) {
                    Label("\(thread.repliesCount)", systemImage: "bubble.right")
                    Label("\(thread.likesCount)", systemImage: "heart")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ThreadsFeedView()
            .navigationTitle("Threads")
    }
}
