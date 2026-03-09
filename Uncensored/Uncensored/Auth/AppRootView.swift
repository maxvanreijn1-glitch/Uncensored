//
//  AppRootView.swift
//  Uncensored
//

import SwiftUI

/// Routes the user to the correct screen based on authentication / profile state.
struct AppRootView: View {

    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        Group {
            switch authVM.authState {
            case .loading:
                splashView

            case .signedOut:
                LoginView()
                    .environmentObject(authVM)

            case .needsUsername(let uid):
                UsernameSetupView(uid: uid)
                    .environmentObject(authVM)

            case .signedIn(let profile):
                MainTabView(profile: profile)
                    .environmentObject(authVM)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.authState)
    }

    private var splashView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Uncensored")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
        }
    }
}

#Preview {
    AppRootView()
}
