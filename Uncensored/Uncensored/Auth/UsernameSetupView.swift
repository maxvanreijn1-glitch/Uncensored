//
//  UsernameSetupView.swift
//  Uncensored
//

import SwiftUI
import PhotosUI

/// Onboarding screen shown when the user is authenticated but hasn't set a username yet.
/// Collects avatar, username, display name, and bio in one step.
struct UsernameSetupView: View {

    let uid: String

    @EnvironmentObject private var authVM: AuthViewModel

    // MARK: - Form state
    @State private var username = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var avatarData: Data?

    // MARK: - UI state
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let bioLimit = 160

    // MARK: - Validation

    private var usernameValidation: UsernameValidationState {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed.count < 3 { return .tooShort }
        if trimmed.count > 30 { return .tooLong }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) { return .invalidChars }
        return .valid
    }

    private var isFormValid: Bool {
        usernameValidation == .valid && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 20)

                    // Header
                    VStack(spacing: 8) {
                        Text("Set Up Your Profile")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        Text("This is how you'll appear on Uncensored.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }

                    // Avatar picker
                    avatarSection

                    // Form fields
                    VStack(spacing: 16) {
                        usernameField
                        displayNameField
                        bioField
                    }
                    .padding(.horizontal, 24)

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Continue button
                    continueButton

                    // Sign out link
                    Button("Sign out") { authVM.signOut() }
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 32)
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Subviews

    private var avatarSection: some View {
        PhotosPicker(selection: $avatarItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let avatarImage {
                        avatarImage
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 56))
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))

                // Camera badge
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                    )
                    .offset(x: 4, y: 4)
            }
        }
        .onChange(of: avatarItem) { _, item in
            Task { await loadAvatar(from: item) }
        }
    }

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Username")
                .font(.caption)
                .foregroundColor(.gray)
            HStack {
                Text("@")
                    .foregroundColor(.gray)
                TextField("", text: $username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(.white)
                    .onChange(of: username) { _, value in
                        // Display lowercase in real-time so the user sees exactly what will be saved
                        let lowered = value.lowercased()
                        if lowered != value { username = lowered }
                    }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(usernameValidation.borderColor, lineWidth: 1)
            )

            if usernameValidation.hint != nil {
                Text(usernameValidation.hint!)
                    .font(.caption2)
                    .foregroundColor(usernameValidation.hintColor)
            }
        }
    }

    private var displayNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Display Name")
                .font(.caption)
                .foregroundColor(.gray)
            TextField("Your name", text: $displayName)
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
    }

    private var bioField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bio")
                .font(.caption)
                .foregroundColor(.gray)
            ZStack(alignment: .topLeading) {
                if bio.isEmpty {
                    Text("Tell people about yourself…")
                        .foregroundColor(.gray)
                        .padding(.top, 12)
                        .padding(.leading, 4)
                }
                TextEditor(text: $bio)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white)
                    .frame(minHeight: 80, maxHeight: 120)
                    .onChange(of: bio) { _, value in
                        if value.count > bioLimit {
                            bio = String(value.prefix(bioLimit))
                        }
                    }
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            HStack {
                Spacer()
                Text("\(bio.count)/\(bioLimit)")
                    .font(.caption2)
                    .foregroundColor(bio.count >= bioLimit ? .red : .gray)
            }
        }
    }

    private var continueButton: some View {
        Button {
            Task { await save() }
        } label: {
            if isLoading {
                ProgressView()
                    .tint(.black)
                    .frame(maxWidth: .infinity, minHeight: 50)
            } else {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
        }
        .background(isFormValid ? Color.white : Color.gray)
        .cornerRadius(25)
        .padding(.horizontal, 24)
        .disabled(!isFormValid || isLoading)
    }

    // MARK: - Actions

    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        avatarData = data
        if let uiImage = UIImage(data: data) {
            avatarImage = Image(uiImage: uiImage)
        }
    }

    private func save() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            try await authVM.saveProfile(
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarData: avatarData
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Username validation helpers

private enum UsernameValidationState: Equatable {
    case empty, tooShort, tooLong, invalidChars, valid

    var borderColor: Color {
        switch self {
        case .empty:        return Color.white.opacity(0.1)
        case .valid:        return Color.green.opacity(0.7)
        default:            return Color.red.opacity(0.7)
        }
    }

    var hint: String? {
        switch self {
        case .empty:        return nil
        case .tooShort:     return "Minimum 3 characters"
        case .tooLong:      return "Maximum 30 characters"
        case .invalidChars: return "Only letters, numbers, and underscores"
        case .valid:        return nil
        }
    }

    var hintColor: Color { .red }
}

#Preview {
    UsernameSetupView(uid: "preview-uid")
        .environmentObject(AuthViewModel())
}
