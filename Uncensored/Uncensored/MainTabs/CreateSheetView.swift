//
//  CreateSheetView.swift
//  Uncensored
//

import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore

/// Sheet opened by the centre "+" tab button.
/// Provides a tabbed interface to post a video or compose a thread.
struct CreateSheetView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var selectedTab: CreateTab = .thread

    enum CreateTab: String, CaseIterable {
        case video = "Video"
        case thread = "Thread"

        var icon: String {
            switch self {
            case .video:  return "video.fill"
            case .thread: return "text.bubble.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Create", selection: $selectedTab) {
                    ForEach(CreateTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                // Tab content
                switch selectedTab {
                case .video:
                    VideoCreateView()
                        .environmentObject(authVM)
                        .id("video")
                case .thread:
                    InlineCreateThreadView(onPosted: { dismiss() })
                        .environmentObject(authVM)
                        .id("thread")
                }
            }
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Inline thread creation (embedded in the sheet)

private struct InlineCreateThreadView: View {

    var onPosted: () -> Void

    @EnvironmentObject private var authVM: AuthViewModel
    @State private var bodyText = ""
    @State private var isPosting = false
    @State private var errorMessage: String?

    private let maxLength = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .topLeading) {
                if bodyText.isEmpty {
                    Text("What's on your mind?")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $bodyText)
                    .frame(minHeight: 160)
                    .onChange(of: bodyText) { value in
                        if value.count > maxLength {
                            bodyText = String(value.prefix(maxLength))
                        }
                    }
            }
            .padding(.horizontal)

            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Spacer()
                Text("\(bodyText.count)/\(maxLength)")
                    .font(.caption)
                    .foregroundColor(bodyText.count >= maxLength ? .red : .secondary)
                    .padding(.trailing)
            }

            Button {
                Task { await post() }
            } label: {
                if isPosting {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text("Post Thread")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 8)
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
            onPosted()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPosting = false
    }
}

#Preview {
    CreateSheetView()
        .environmentObject(AuthViewModel())
}

