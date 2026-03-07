//
//  UsernameSetupView.swift
//  Uncensored
//

import SwiftUI

/// Onboarding screen shown when the user is authenticated but hasn't set a username yet.
struct UsernameSetupView: View {

    let uid: String

    @EnvironmentObject private var authVM: AuthViewModel
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 && trimmed.count <= 30
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(.white)

                Text("Pick a username")
                    .font(.title.bold())
                    .foregroundColor(.white)

                Text("Your username is how people find you on Uncensored.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                TextField("Username", text: $username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

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
                .background(isValid ? Color.white : Color.gray)
                .cornerRadius(25)
                .padding(.horizontal, 32)
                .disabled(!isValid || isLoading)

                Spacer()

                Button("Sign out") {
                    authVM.signOut()
                }
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 32)
            }
        }
    }

    private func save() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authVM.saveUsername(username.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    UsernameSetupView(uid: "preview-uid")
        .environmentObject(AuthViewModel())
}
