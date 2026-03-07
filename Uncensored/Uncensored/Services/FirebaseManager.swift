//
//  FirebaseManager.swift
//  Uncensored
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// Central access point for Firebase shared service instances.
final class FirebaseManager {

    static let shared = FirebaseManager()

    let auth: Auth
    let firestore: Firestore
    let storage: Storage

    private init() {
        auth = Auth.auth()
        firestore = Firestore.firestore()
        storage = Storage.storage()
    }
}
