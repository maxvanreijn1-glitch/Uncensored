# Uncensored

A TikTok-like iOS app built with SwiftUI, Firebase, and Google Sign-In.

---

## Firebase Setup

### 1. Create a Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** and follow the prompts.
3. Enable **Authentication** (Apple, Google, Email/Password, Phone).
4. Enable **Cloud Firestore** (start in test mode for development).
5. Enable **Firebase Storage**.

### 2. Add the iOS app to your Firebase project

1. In the Firebase Console, click **Add app → iOS+**.
2. Enter the bundle ID: `com.maxvanreijn1.uncensored.Uncensored`.
3. Download `GoogleService-Info.plist` and **drag it into** the `Uncensored/Uncensored/` folder in Xcode (make sure "Copy items if needed" is checked and the file is added to the `Uncensored` target).

> ⚠️ **Never commit `GoogleService-Info.plist` to the repository.** It is listed in `.gitignore`.

### 3. Set the URL scheme for Google Sign-In

1. Open `Uncensored.xcodeproj` in Xcode.
2. Select the **Uncensored** target → **Info** tab → **URL Types**.
3. Add a new URL Type:
   - **Identifier**: `com.googleusercontent.apps`
   - **URL Schemes**: paste the value of `REVERSED_CLIENT_ID` from `GoogleService-Info.plist`
     (it looks like `com.googleusercontent.apps.XXXXXXXXX-XXXX`)

### 4. Install Swift Package dependencies

The project uses Swift Package Manager. Open `Uncensored.xcodeproj`; Xcode will automatically
resolve these packages on first open:

| Package | Version |
|---------|---------|
| [firebase/firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk) | ≥ 11.0.0 |
| [google/GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS) | ≥ 7.0.0 |

---

## Project Structure

```
Uncensored/Uncensored/
├── UncensoredApp.swift          # App entry point – configures Firebase
├── Auth/
│   ├── AppRootView.swift        # Auth-gated root view
│   ├── AuthViewModel.swift      # Auth state machine (ObservableObject)
│   ├── LoginView.swift          # TikTok-style login screen
│   └── UsernameSetupView.swift  # Post-login username onboarding
├── MainTabs/
│   ├── MainTabView.swift        # 5-tab TikTok-like navigation
│   └── CreateSheetView.swift    # "+" action sheet
├── Video/
│   ├── VideoFeedView.swift      # Vertical video feed (placeholder)
│   └── VideoCreateView.swift    # Pick/record + upload flow
├── Threads/
│   ├── ThreadsFeedView.swift    # Text threads feed
│   ├── ThreadDetailView.swift   # Thread + replies
│   └── CreateThreadView.swift   # Compose thread
├── Messages/
│   ├── MessagesView.swift       # Conversation inbox
│   └── ChatView.swift           # 1-on-1 chat
├── Profile/
│   └── ProfileView.swift        # User profile
├── Services/
│   ├── FirebaseManager.swift    # Shared Firebase instances
│   └── VideoUploadService.swift # Storage + Firestore video upload
└── Models/
    ├── UserProfile.swift
    ├── VideoModel.swift
    └── ThreadModel.swift
```

---

## Firestore Data Model

| Collection | Document | Fields |
|------------|----------|--------|
| `users` | `{uid}` | username, displayName, bio, avatarURL, followersCount, followingCount, videosCount, createdAt |
| `videos` | `{videoId}` | authorId, videoURL, thumbnailURL, caption, likesCount, commentsCount, sharesCount, createdAt |
| `threads` | `{threadId}` | authorId, authorUsername, body, likesCount, repliesCount, createdAt |

---

## Requirements

- Xcode 15 or later
- iOS 16.0+ deployment target
- `GoogleService-Info.plist` (not included – see setup above)
