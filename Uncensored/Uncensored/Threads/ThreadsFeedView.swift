//
//  ThreadsFeedView.swift
//  Uncensored
//

import SwiftUI

/// Twitter/Threads-style text feed with real Firestore pagination.
struct ThreadsFeedView: View {

    @StateObject private var viewModel = ThreadsFeedViewModel()

    var body: some View {
        List {
            ForEach(viewModel.threads) { thread in
                NavigationLink(destination: ThreadDetailView(thread: thread)) {
                    ThreadRowView(
                        thread: thread,
                        isLiked: viewModel.likeBinding(for: thread),
                        onLike: { viewModel.toggleLike(for: thread) }
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
                VStack(spacing: 16) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No threads yet")
                        .font(.title3.bold())
                    Text("Be the first to post a thread!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Thread Row

struct ThreadRowView: View {
    let thread: ThreadModel
    @Binding var isLiked: Bool
    var onLike: () -> Void

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
                        // TODO: Share sheet
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
    }
}
