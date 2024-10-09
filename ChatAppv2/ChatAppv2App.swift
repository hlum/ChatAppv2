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
    @State var isActive = false
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
//            OnboardingView(isUserCurrentlyLoggedOut: .constant(true))
            SplashView(isAvtive: $isActive)
        }
    }

    // AppDelegate class that conforms to UIApplicationDelegate
    class AppDelegate: NSObject, UIApplicationDelegate {
        
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            // Your custom configuration
            FirebaseApp.configure()
            return true
        }
    }
}



