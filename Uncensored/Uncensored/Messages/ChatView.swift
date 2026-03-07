//
//  ChatView.swift
//  Uncensored
//

import SwiftUI

/// Individual chat conversation screen.
struct ChatView: View {

    let participantName: String

    // TODO: Replace with real messages from Firestore.
    @State private var messages: [ChatMessage] = [
        ChatMessage(id: "1", text: "Hey there!", isFromMe: false),
        ChatMessage(id: "2", text: "Hi! How are you?", isFromMe: true),
        ChatMessage(id: "3", text: "Great, thanks for asking!", isFromMe: false),
    ]
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                TextField("Message…", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(inputText.isEmpty ? .secondary : .accentColor)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle("@\(participantName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isFromMe { Spacer(minLength: 60) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isFromMe ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(message.isFromMe ? .white : .primary)
                .cornerRadius(18)
            if !message.isFromMe { Spacer(minLength: 60) }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(id: UUID().uuidString, text: text, isFromMe: true))
        inputText = ""
        // TODO: Persist message to Firestore.
    }
}

private struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let isFromMe: Bool
}

#Preview {
    NavigationStack {
        ChatView(participantName: "previewuser")
    }
}
