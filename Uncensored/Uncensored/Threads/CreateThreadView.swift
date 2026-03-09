//
//  CreateThreadView.swift
//  Uncensored
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Compose and post a new thread.
struct CreateThreadView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var bodyText = ""
    @State private var isPosting = false
    @State private var errorMessage: String?

    private let maxLength = 500

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextEditor(text: $bodyText)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .onChange(of: bodyText) { value in
                        if value.count > maxLength {
                            bodyText = String(value.prefix(maxLength))
                        }
                    }

                HStack {
                    Spacer()
                    Text("\(bodyText.count)/\(maxLength)")
                        .font(.caption)
                        .foregroundColor(bodyText.count >= maxLength ? .red : .secondary)
                        .padding(.trailing)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("New Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isPosting {
                        ProgressView()
                    } else {
                        Button("Post") {
                            Task { await post() }
                        }
                        .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .bold()
                    }
                }
            }
        }
    }

    private func post() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be signed in."
            return
        }
        let authorUsername = authVM.currentUsername.isEmpty ? "anonymous" : authVM.currentUsername
        isPosting = true
        errorMessage = nil
        let threadId = UUID().uuidString
        let thread = ThreadModel(
            id: threadId,
            authorId: uid,
            authorUsername: authorUsername,
            body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            likesCount: 0,
            repliesCount: 0,
            createdAt: Date()
        )
        do {
            let data = try Firestore.Encoder().encode(thread)
            try await FirebaseManager.shared.firestore
                .collection("threads")
                .document(threadId)
                .setData(data)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPosting = false
    }
}

#Preview {
    CreateThreadView()
        .environmentObject(AuthViewModel())
}
