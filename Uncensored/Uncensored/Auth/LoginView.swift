//
//  LoginView.swift
//  Uncensored
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

/// TikTok-style login landing screen.
struct LoginView: View {

    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showEmailLogin = false
    @State private var showPhoneLogin = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / App name
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    Text("Uncensored")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("The place for unfiltered content.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 60)

                // Auth buttons
                VStack(spacing: 14) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Continue with Apple
                    SignInWithAppleButton(.continue) { request in
                        handleAppleRequest(request)
                    } onCompletion: { result in
                        handleAppleCompletion(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(25)
                    .padding(.horizontal, 32)

                    // Continue with Google
                    Button(action: signInWithGoogle) {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Text("Continue with Google")
                                .font(.headline)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.white)
                        .cornerRadius(25)
                        .padding(.horizontal, 32)
                    }

                    // Use phone
                    Button(action: { showPhoneLogin = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "phone.fill")
                                .font(.title3)
                            Text("Use phone")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(25)
                        .padding(.horizontal, 32)
                    }

                    // Use email
                    Button(action: { showEmailLogin = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.title3)
                            Text("Use email")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(25)
                        .padding(.horizontal, 32)
                    }
                }

                Spacer()

                Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showEmailLogin) {
            EmailLoginView()
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showPhoneLogin) {
            PhoneLoginView()
        }
    }

    // MARK: - Google Sign-In

    private func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error {
                errorMessage = error.localizedDescription
                return
            }
            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                errorMessage = "Google sign-in failed."
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { _, error in
                if let error {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Apple Sign-In

    // TODO: Generate and store a cryptographically random nonce here using
    // CryptoKit (SHA256) when implementing the full Sign in with Apple flow.
    // See: https://firebase.google.com/docs/auth/ios/apple

    private func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        // TODO: Generate and store a secure nonce for Apple Sign-In.
        // See: https://firebase.google.com/docs/auth/ios/apple
        request.requestedScopes = [.fullName, .email]
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard
                let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = appleCredential.identityToken,
                let tokenString = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple sign-in failed."
                return
            }
            // TODO: Use a real nonce in production.
            let credential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nil,
                fullName: appleCredential.fullName
            )
            Auth.auth().signIn(with: credential) { _, error in
                if let error {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Email Login (placeholder sheet)

private struct EmailLoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                Button(isSignUp ? "Create account" : "Sign in") {
                    Task { await submit() }
                }
                .buttonStyle(.borderedProminent)
                Button(isSignUp ? "Already have an account?" : "Create account") {
                    isSignUp.toggle()
                }
                .font(.caption)
            }
            .padding()
            .navigationTitle(isSignUp ? "Sign up" : "Sign in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        do {
            if isSignUp {
                try await Auth.auth().createUser(withEmail: email, password: password)
            } else {
                try await Auth.auth().signIn(withEmail: email, password: password)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Phone Login (placeholder sheet)

private struct PhoneLoginView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("Phone sign-in coming soon.")
                    .font(.headline)
                Text("TODO: Implement SMS OTP flow with FirebaseAuth PhoneAuthProvider.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .navigationTitle("Phone sign-in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
