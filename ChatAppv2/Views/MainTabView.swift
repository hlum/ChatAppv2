//
//  MainTabView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 9/26/24.
//

import SwiftUI

class MainTabViewModel:ObservableObject{
    @Published var user:DBUser? = nil
    
    init(){
        Task{
            await fetchCurrentUser()
        }
    }
    
    private func fetchCurrentUser()async{
        guard let authDataResult = try? AuthenticationManager.shared.getAuthenticatedUser() else {
            print("Error: No authenticated user")
            return
        }
        let user = try? await UserManager.shared.getUser(userId: authDataResult.uid)

        DispatchQueue.main.async {
            self.user = user
        }
    }
}

struct MainTabView: View {
    @StateObject var vm = MainTabViewModel()
    var body: some View {
        TabView {
            RecentMessagesView()
                .tabItem {
                    Image(systemName: "message.fill")
                }
            if let currentUser = vm.user{
                FindNewFriendView(currentUser: currentUser)
                    .tabItem {
                        Image(systemName: "person.2.fill")
                    }
            }
        }
    }
}

#Preview {
    MainTabView()
}
