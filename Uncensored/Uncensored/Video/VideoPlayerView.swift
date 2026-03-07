//
//  VideoPlayerView.swift
//  Uncensored
//

import SwiftUI
import AVKit

/// Full-screen AVPlayer wrapper for a single video URL.
/// Automatically plays when the view appears and pauses on disappear.
struct VideoPlayerView: View {

    let url: URL
    let isActive: Bool

    @State private var player: AVPlayer?
    @State private var loopObserver: Any?

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .onAppear {
                setupPlayer(url: url)
            }
            .onDisappear {
                teardownPlayer()
            }
            .onChange(of: isActive) { active in
                if active {
                    player?.seek(to: .zero)
                    player?.play()
                } else {
                    player?.pause()
                }
            }
            .onChange(of: url) { newURL in
                teardownPlayer()
                setupPlayer(url: newURL)
            }
    }

    private func setupPlayer(url: URL) {
        let newPlayer = AVPlayer(url: url)
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            if isActive { newPlayer.play() }
        }
        loopObserver = observer
        player = newPlayer
        if isActive { newPlayer.play() }
    }

    private func teardownPlayer() {
        player?.pause()
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        player = nil
    }
}
