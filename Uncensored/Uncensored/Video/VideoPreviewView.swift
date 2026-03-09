//
//  VideoPreviewView.swift
//  Uncensored
//

import SwiftUI
import AVKit

// MARK: - VideoPreviewView

/// Shown immediately after recording. Lets the user loop-preview the video,
/// then either retake (discard) or proceed (use the clip).
struct VideoPreviewView: View {

    let videoURL: URL
    let onRetake: () -> Void
    let onUseVideo: (URL) -> Void

    @State private var player: AVPlayer
    @State private var loopObserver: NSObjectProtocol?

    init(videoURL: URL, onRetake: @escaping () -> Void, onUseVideo: @escaping (URL) -> Void) {
        self.videoURL = videoURL
        self.onRetake = onRetake
        self.onUseVideo = onUseVideo
        _player = State(initialValue: AVPlayer(url: videoURL))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Full-screen looping player
            VideoPlayer(player: player)
                .ignoresSafeArea()

            // UI overlay
            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .onAppear {
            player.play()
            setupLoop()
        }
        .onDisappear {
            player.pause()
            if let token = loopObserver {
                NotificationCenter.default.removeObserver(token)
                loopObserver = nil
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                player.pause()
                onRetake()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Retake")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.5))
                .cornerRadius(22)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Button {
                player.pause()
                onUseVideo(videoURL)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                    Text("Use This Video")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(14)
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 48)
    }

    // MARK: - Helpers

    private func setupLoop() {
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }
}
