//
//  VideoCreateView.swift
//  Uncensored
//

import SwiftUI
import PhotosUI
import FirebaseAuth

/// Lets the user pick a video from library or record in-app, then upload it.
struct VideoCreateView: View {

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var showRecorder = false
    @State private var caption = ""
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?
    @State private var uploadSuccess = false

    private let uploadService = VideoUploadService()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if let _ = selectedVideoURL {
                    previewView
                } else {
                    selectionView
                }
            }
            .navigationTitle("New Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .alert("Upload complete!", isPresented: $uploadSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your video has been published.")
        }
    }

    // MARK: - Selection screen

    private var selectionView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Pick from library
            PhotosPicker(
                selection: $selectedItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                    Text("Pick from Library")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal, 24)
            }
            .onChange(of: selectedItem) { _, item in
                Task { await loadVideo(from: item) }
            }

            // Record in app
            Button {
                showRecorder = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                    Text("Record Video")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color.red.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal, 24)
            }
            .foregroundColor(.red)

            Spacer()
        }
        .sheet(isPresented: $showRecorder) {
            VideoRecorderView(onVideoRecorded: { url in
                selectedVideoURL = url
            })
        }
    }

    // MARK: - Preview / caption screen

    private var previewView: some View {
        VStack(spacing: 20) {
            // Placeholder for video preview thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .aspectRatio(9/16, contentMode: .fit)
                    .padding(.horizontal, 48)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white.opacity(0.8))
            }

            TextField("Write a caption…", text: $caption, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3)
                .padding(.horizontal)

            if let error = errorMessage {
                Text(error).foregroundColor(.red).font(.caption)
            }

            if isUploading {
                ProgressView(value: uploadProgress)
                    .padding(.horizontal)
                Text("\(Int(uploadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button("Post Video") {
                    Task { await upload() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUploading)
            }

            Button("Choose different video") {
                selectedVideoURL = nil
                selectedItem = nil
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.top)
    }

    // MARK: - Helpers

    private func loadVideo(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let url = try await item.loadTransferable(type: VideoTransferable.self) {
                selectedVideoURL = url.url
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upload() async {
        guard let videoURL = selectedVideoURL,
              let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be signed in to upload."
            return
        }
        isUploading = true
        errorMessage = nil
        uploadService.uploadVideo(
            fileURL: videoURL,
            caption: caption,
            authorId: uid,
            progress: { value in
                Task { @MainActor in uploadProgress = value }
            }
        ) { result in
            Task { @MainActor in
                isUploading = false
                switch result {
                case .success:
                    uploadSuccess = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - VideoTransferable

/// Bridges `PhotosPickerItem` to a local file URL.
private struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mp4")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return VideoTransferable(url: dest)
        }
    }
}

// MARK: - VideoRecorderView (placeholder)

/// Placeholder camera recorder UI. Replace with full AVFoundation implementation.
struct VideoRecorderView: View {

    var onVideoRecorded: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "camera.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.white)
                Text("Camera Recorder")
                    .font(.title.bold())
                    .foregroundColor(.white)
                Text("TODO: Implement AVCaptureSession-based video recorder here.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                // Simulate a recorded video for development
                Button("Simulate recording") {
                    let placeholder = FileManager.default.temporaryDirectory
                        .appendingPathComponent("placeholder.mp4")
                    FileManager.default.createFile(atPath: placeholder.path, contents: nil)
                    onVideoRecorded(placeholder)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Button("Cancel") { dismiss() }
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    VideoCreateView()
}
