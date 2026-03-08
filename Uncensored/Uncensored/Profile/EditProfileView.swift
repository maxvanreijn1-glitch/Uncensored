//
//  EditProfileView.swift
//  Uncensored
//

import SwiftUI
import PhotosUI

/// Lets the user edit their profile: display name, bio, avatar, and privacy setting.
struct EditProfileView: View {

    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var bio: String
    @State private var isPrivate: Bool
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(profile: UserProfile) {
        _displayName = State(initialValue: profile.displayName)
        _bio = State(initialValue: profile.bio)
        _isPrivate = State(initialValue: profile.isPrivate)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Avatar
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            avatarPreview
                        }
                        .onChange(of: selectedItem) { _, item in
                            Task { await loadImage(from: item) }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Profile Info") {
                    LabeledContent("Username") {
                        Text("@\(authVM.currentUsername)")
                            .foregroundColor(.secondary)
                    }

                    TextField("Display Name", text: $displayName)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Privacy") {
                    Toggle("Private Account", isOn: $isPrivate)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .bold()
                    }
                }
            }
        }
    }

    // MARK: - Avatar preview

    private var avatarPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let data = selectedImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if let avatarURLString = authVM.currentProfile?.avatarURL,
                          let avatarURL = URL(string: avatarURLString) {
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())

            Circle()
                .fill(Color.accentColor)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                )
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.3))
            .overlay(
                Text(authVM.currentUsername.prefix(1).uppercased())
                    .font(.largeTitle.bold())
            )
    }

    // MARK: - Helpers

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                selectedImageData = data
            }
        } catch {
            errorMessage = "Failed to load image."
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await authVM.updateProfile(
                displayName: displayName,
                bio: bio,
                isPrivate: isPrivate,
                avatarData: selectedImageData
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

#Preview {
    EditProfileView(profile: UserProfile(
        id: "preview",
        username: "previewuser",
        displayName: "Preview User",
        bio: "Hello world",
        avatarURL: nil,
        followersCount: 0,
        followingCount: 0,
        videosCount: 0,
        isPrivate: false,
        createdAt: Date()
    ))
    .environmentObject(AuthViewModel())
}
