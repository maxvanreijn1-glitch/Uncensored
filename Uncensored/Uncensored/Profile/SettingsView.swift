//
//  SettingsView.swift
//  Uncensored
//

import SwiftUI
import FirebaseAuth

/// Full settings page with account, notifications, privacy, content, and app sections.
struct SettingsView: View {

    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Notification settings
    @AppStorage("notif_likes") private var notifLikes = true
    @AppStorage("notif_comments") private var notifComments = true
    @AppStorage("notif_followers") private var notifFollowers = true
    @AppStorage("notif_messages") private var notifMessages = true

    // Content settings
    @AppStorage("explicit_content") private var explicitContent = false
    @AppStorage("video_quality") private var videoQuality = "Medium"
    @AppStorage("autoplay") private var autoplay = true

    // App settings
    @AppStorage("dark_mode") private var darkMode = true

    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showEditProfile = false
    @State private var errorMessage: String?

    private let videoQualities = ["Low", "Medium", "High"]

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                notificationSection
                privacySection
                contentSection
                appSection
                dangerZoneSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let profile = authVM.currentProfile {
                    EditProfileView(profile: profile)
                        .environmentObject(authVM)
                }
            }
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { authVM.signOut() }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .confirmationDialog("Delete Account", isPresented: $showDeleteAccountConfirm, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) { deleteAccount() }
            } message: {
                Text("This action is irreversible. All your data will be permanently deleted.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section("Account") {
            LabeledContent("Username") {
                Text("@\(authVM.currentUsername)")
                    .foregroundColor(.secondary)
            }
            Button("Edit Profile") { showEditProfile = true }
        }
    }

    private var notificationSection: some View {
        Section("Notifications") {
            Toggle("Likes", isOn: $notifLikes)
            Toggle("Comments", isOn: $notifComments)
            Toggle("New Followers", isOn: $notifFollowers)
            Toggle("Messages", isOn: $notifMessages)
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            if let profile = authVM.currentProfile {
                Toggle("Private Account", isOn: Binding(
                    get: { profile.isPrivate },
                    set: { newValue in
                        Task {
                            try? await authVM.updateProfile(
                                displayName: profile.displayName,
                                bio: profile.bio,
                                isPrivate: newValue,
                                avatarData: nil
                            )
                        }
                    }
                ))
            }
        }
    }

    private var contentSection: some View {
        Section("Content") {
            Toggle("Explicit Content", isOn: $explicitContent)
            Picker("Video Quality", selection: $videoQuality) {
                ForEach(videoQualities, id: \.self) { q in
                    Text(q).tag(q)
                }
            }
            Toggle("Auto-play Videos", isOn: $autoplay)
        }
    }

    private var appSection: some View {
        Section("App") {
            Toggle("Dark Mode", isOn: $darkMode)
            Button {
                clearCache()
            } label: {
                Label("Clear Cache", systemImage: "trash.circle")
            }
            NavigationLink {
                aboutView
            } label: {
                Label("About", systemImage: "info.circle")
            }
        }
    }

    private var dangerZoneSection: some View {
        Section {
            Button {
                showSignOutConfirm = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
            }

            Button(role: .destructive) {
                showDeleteAccountConfirm = true
            } label: {
                Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
            }
        }
    }

    private var aboutView: some View {
        Form {
            Section("About Uncensored") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.secondary)
                }
                LabeledContent("Build") {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func clearCache() {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let cacheURL else { return }
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheURL, includingPropertiesForKeys: nil
            )
            for file in contents {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            // Silently fail
        }
    }

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        user.delete { error in
            if let error {
                errorMessage = error.localizedDescription
            }
            // Auth state listener will sign the user out automatically
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
