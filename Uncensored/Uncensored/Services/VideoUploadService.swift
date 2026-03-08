//
//  VideoUploadService.swift
//  Uncensored
//

import Foundation
import FirebaseStorage
import FirebaseFirestore

/// Handles uploading a video file to Firebase Storage and persisting metadata to Firestore.
final class VideoUploadService {

    private let storage = FirebaseManager.shared.storage
    private let firestore = FirebaseManager.shared.firestore

    /// Uploads a video from a local URL, then writes a Firestore document.
    /// - Parameters:
    ///   - fileURL: Local file URL of the video to upload.
    ///   - caption: User-provided caption.
    ///   - authorId: The UID of the authenticated user.
    ///   - authorUsername: The Firestore username of the author.
    ///   - progress: Optional closure called with upload progress (0.0 – 1.0).
    ///   - completion: Called when finished, with the new `VideoModel` or an error.
    func uploadVideo(
        fileURL: URL,
        caption: String,
        authorId: String,
        authorUsername: String,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<VideoModel, Error>) -> Void
    ) {
        let videoId = UUID().uuidString
        let storageRef = storage.reference().child("videos/\(videoId).mp4")

        let uploadTask = storageRef.putFile(from: fileURL, metadata: nil) { [weak self] _, error in
            if let error {
                completion(.failure(error))
                return
            }
            storageRef.downloadURL { url, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let downloadURL = url else {
                    completion(.failure(NSError(domain: "VideoUploadService",
                                                code: -1,
                                                userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    return
                }
                self?.saveVideoDocument(
                    videoId: videoId,
                    videoURL: downloadURL.absoluteString,
                    caption: caption,
                    authorId: authorId,
                    authorUsername: authorUsername,
                    completion: completion
                )
            }
        }

        uploadTask.observe(.progress) { snapshot in
            guard let progressValue = snapshot.progress?.fractionCompleted else { return }
            progress?(progressValue)
        }
    }

    private func saveVideoDocument(
        videoId: String,
        videoURL: String,
        caption: String,
        authorId: String,
        authorUsername: String,
        completion: @escaping (Result<VideoModel, Error>) -> Void
    ) {
        let model = VideoModel(
            id: videoId,
            authorId: authorId,
            authorUsername: authorUsername,
            videoURL: videoURL,
            thumbnailURL: nil,
            caption: caption,
            likesCount: 0,
            commentsCount: 0,
            sharesCount: 0,
            createdAt: Date()
        )
        do {
            let data = try Firestore.Encoder().encode(model)
            firestore.collection("videos").document(videoId).setData(data) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(model))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}
