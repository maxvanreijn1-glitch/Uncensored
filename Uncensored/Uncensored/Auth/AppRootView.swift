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
        .animation(.easeInOut(duration: 0.3), value: authStateTag)
    }

    private var splashView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Uncensored")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
        }
    }

    /// A simple equatable tag used to drive the state transition animation.
    private var authStateTag: Int {
        switch authVM.authState {
        case .loading:       return 0
        case .signedOut:     return 1
        case .needsUsername: return 2
        case .signedIn:      return 3
        }
    }
}

#Preview {
    AppRootView()
}
