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
    init(){
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            MainMessageView()
        }
    }
}
