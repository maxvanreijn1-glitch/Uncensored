//
//  VideoInteractionView.swift
//  Uncensored
//

import SwiftUI

/// Right-side interaction panel shown over a video (like, comment, share, follow).
struct VideoInteractionView: View {

    let video: VideoModel
    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onFollow: () -> Void

    @Binding var isLiked: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Follow (avatar with + badge)
            Button(action: onFollow) {
                ZStack(alignment: .bottom) {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        )
                    Circle()
                        .fill(Color.red)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(y: 8)
                }
            }

            // Like
            interactionButton(
                icon: isLiked ? "heart.fill" : "heart",
                label: "\(video.likesCount)",
                color: isLiked ? .red : .white,
                action: onLike
            )

            // Comment
            interactionButton(
                icon: "bubble.right",
                label: "\(video.commentsCount)",
                color: .white,
                action: onComment
            )

            // Share
            interactionButton(
                icon: "arrowshape.turn.up.right",
                label: "\(video.sharesCount)",
                color: .white,
                action: onShare
            )
        }
        .padding(.trailing, 12)
        .padding(.bottom, 80)
    }

    private func interactionButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .shadow(radius: 2)
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
        }
    }
}
