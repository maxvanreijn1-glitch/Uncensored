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
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        } else {
            print("[UncensoredApp] WARNING: GoogleService-Info.plist not found -- Firebase is not configured.")
        }
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
