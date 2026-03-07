//
//  CreateSheetView.swift
//  Uncensored
//

import SwiftUI

/// Sheet opened by the centre "+" tab button – lets the user choose what to create.
struct CreateSheetView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var showVideoCreate = false
    @State private var showThreadCreate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Create")
                    .font(.title2.bold())
                    .padding(.top, 24)
                    .padding(.bottom, 32)

                Button {
                    showVideoCreate = true
                } label: {
                    createRow(
                        icon: "video.fill",
                        title: "Upload / Record Video",
                        subtitle: "Share a video with the world"
                    )
                }

                Divider().padding(.horizontal)

                Button {
                    showThreadCreate = true
                } label: {
                    createRow(
                        icon: "text.bubble.fill",
                        title: "Create Thread",
                        subtitle: "Share your thoughts"
                    )
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showVideoCreate) {
            VideoCreateView()
        }
        .sheet(isPresented: $showThreadCreate) {
            CreateThreadView()
        }
    }

    private func createRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(12)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundColor(.primary)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

#Preview {
    CreateSheetView()
}
