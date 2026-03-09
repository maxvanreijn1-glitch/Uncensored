//
//  MainTabView.swift
//  Uncensored
//

import SwiftUI

/// TikTok-like 5-tab navigation. The centre tab is a "+" action sheet, not a real tab.
struct MainTabView: View {

    let profile: UserProfile
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var selectedTab: Tab = .home
    @State private var showCreateSheet = false

    enum Tab: Int {
        case home, threads, create, messages, profile
    }

    /// Custom binding that intercepts taps on the "+" tab and opens the create sheet
    /// instead of actually switching to that tab. Using a binding avoids the async delay
    /// that would occur with onChange/onValueChange approaches.
    private var tabSelection: Binding<Tab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == .create {
                    showCreateSheet = true
                    // Do NOT update selectedTab — keep the current tab active.
                } else {
                    selectedTab = newTab
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            // 1 – Home (video feed) — fullscreen, no navigation bar
            VideoFeedView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            // 2 – Threads
            NavigationStack {
                ThreadsFeedView()
                    .navigationTitle("Threads")
            }
            .tabItem { Label("Threads", systemImage: "bubble.left.and.bubble.right.fill") }
            .tag(Tab.threads)

            // 3 – Create (placeholder tab; tap opens sheet)
            Color.clear
                .tabItem { Label("", systemImage: "plus.app.fill") }
                .tag(Tab.create)

            // 4 – Messages
            NavigationStack {
                MessagesView()
                    .navigationTitle("Messages")
            }
            .tabItem { Label("Messages", systemImage: "message.fill") }
            .tag(Tab.messages)

            // 5 – Profile
            NavigationStack {
                ProfileView(profile: profile)
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
            .tag(Tab.profile)
        }
        .tint(.primary)
        .sheet(isPresented: $showCreateSheet) {
            CreateSheetView()
                .environmentObject(authVM)
        }
    }
}

#Preview {
    MainTabView(profile: UserProfile.stub(uid: "preview"))
        .environmentObject(AuthViewModel())
}
