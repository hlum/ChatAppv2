//
//  ChatAppv2App.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import SwiftUI
import Firebase

@main
struct ChatAppv2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        FirebaseApp.configure() // Configure Firebase once
    }

    var body: some Scene {
        WindowGroup {
                MainTabView()
                    .toolbar(.hidden)
        }
    }

    // AppDelegate class that conforms to UIApplicationDelegate
    class AppDelegate: NSObject, UIApplicationDelegate {
        
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            // Your custom configuration
            return true
        }
    }
}



