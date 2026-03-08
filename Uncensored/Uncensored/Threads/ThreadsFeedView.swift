//
//  ThreadsFeedView.swift
//  Uncensored
//

import SwiftUI
import Combine

/// Twitter/Threads-style text feed with real Firestore pagination.
struct ThreadsFeedView: View {

    @StateObject private var viewModel = ThreadsFeedViewModel()
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var threadToDelete: ThreadModel?
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            ForEach(viewModel.threads) { thread in
                NavigationLink(destination: ThreadDetailView(thread: thread)) {
                    ThreadRowView(
                        thread: thread,
                        isLiked: viewModel.likeBinding(for: thread),
                        onLike: { viewModel.toggleLike(for: thread) },
                        onShare: {
                            shareItems = [thread.body]
                            showShareSheet = true
                        },
                        isOwnContent: thread.authorId == authVM.currentUserId,
                        onDelete: {
                            threadToDelete = thread
                            showDeleteConfirm = true
                        }
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
                if #available(iOS 17.0, *) {
                    ContentUnavailableView(
                        "No threads yet",
                        systemImage: "text.bubble",
                        description: Text("Be the first to post a thread!")
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No threads yet")
                            .font(.title3.bold())
                        Text("Be the first to post a thread!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .confirmationDialog("Delete Thread?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let thread = threadToDelete {
                    Task { await viewModel.deleteThread(thread) }
                }
            }
        }
    }
}

// MARK: - Thread Row

struct ThreadRowView: View {
    let thread: ThreadModel
    @Binding var isLiked: Bool
    var onLike: () -> Void
    var onShare: (() -> Void)? = nil
    var isOwnContent: Bool = false
    var onDelete: (() -> Void)? = nil

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
                    if isOwnContent, let onDelete {
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
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
                            "\(thread.likesCount)",
                            systemImage: isLiked ? "heart.fill" : "heart"
                        )
                        .font(.caption)
                        .foregroundColor(isLiked ? .red : .secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onShare?()
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

#Preview {
    NavigationStack {
        ThreadsFeedView()
            .navigationTitle("Threads")
            .environmentObject(AuthViewModel())
    }
}

