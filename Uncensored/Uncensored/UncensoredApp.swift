//
//  UncensoredApp.swift
//  Uncensored
//
//  Created by Max Watson on 07/03/2026.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct UncensoredApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .onOpenURL { url in
                    // Required for Google Sign-In redirect to complete.
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
