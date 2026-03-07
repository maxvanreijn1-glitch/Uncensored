//
//  VideoFeedView.swift
//  Uncensored
//

import SwiftUI

/// Vertical full-screen video feed placeholder (TikTok-style).
struct VideoFeedView: View {

    // TODO: Replace with real data fetched from Firestore.
    private let placeholderCount = 5

    var body: some View {
        TabView {
            ForEach(0..<placeholderCount, id: \.self) { index in
                videoCard(index: index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }

    private func videoCard(index: Int) -> some View {
        ZStack {
            Color(hue: Double(index) / Double(placeholderCount), saturation: 0.6, brightness: 0.3)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.8))
                Text("Video \(index + 1)")
                    .font(.title.bold())
                    .foregroundColor(.white)
                Text("Placeholder – integrate AVPlayer here")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

#Preview {
    VideoFeedView()
}
