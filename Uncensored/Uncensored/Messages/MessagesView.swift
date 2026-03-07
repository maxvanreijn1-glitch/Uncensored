//
//  MessagesView.swift
//  Uncensored
//

import SwiftUI

/// Inbox listing of conversations.
struct MessagesView: View {

    // TODO: Fetch real conversations from Firestore.
    private let conversations: [ConversationStub] = (1...6).map { i in
        ConversationStub(
            id: UUID().uuidString,
            participantName: "user\(i)",
            lastMessage: "Hey, this is a placeholder message #\(i) 👋",
            unread: i % 2 == 0,
            timestamp: Date().addingTimeInterval(TimeInterval(-i * 3600))
        )
    }

    var body: some View {
        List(conversations) { convo in
            NavigationLink(destination: ChatView(participantName: convo.participantName)) {
                conversationRow(convo)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Messages")
    }

    private func conversationRow(_ convo: ConversationStub) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: 48, height: 48)
                .overlay(Text(convo.participantName.prefix(1).uppercased()).font(.headline))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@\(convo.participantName)")
                        .font(.headline)
                    if convo.unread {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                    }
                    Spacer()
                    Text(convo.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(convo.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ConversationStub: Identifiable {
    let id: String
    let participantName: String
    let lastMessage: String
    let unread: Bool
    let timestamp: Date
}

#Preview {
    NavigationStack {
        MessagesView()
    }
}
