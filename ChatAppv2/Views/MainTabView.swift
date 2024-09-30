//
//  MainTabView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 9/26/24.
//

import SwiftUI
import SDWebImageSwiftUI

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


enum TabItems:Int,CaseIterable{
    case RecentMessagesView = 0
    case FindNewFriendView = 1
    case ProfileView = 2
    
    var Title:String{
        switch self{
        case .RecentMessagesView:
            "Messages"
        case .FindNewFriendView:
            "Find New Friend"
        case .ProfileView:
            "Profile"
        }
    }
    
    var imageName:String{
        switch self{
        case .RecentMessagesView:
            "message.fill"
        case .FindNewFriendView:
            "person.2.badge.plus.fill"
        case .ProfileView:
            "person.circle.fill"
        }
    }
}

struct MainTabView: View {
    @StateObject var vm = MainTabViewModel()
    
    @State var tabSelection: Int = 0
    var body: some View {
        ZStack(alignment:.bottom){
            TabView (selection:$tabSelection){
                RecentMessagesView(tabSelection: $tabSelection)
                    .tag(0)
                if let currentUser = vm.user{
                    FindNewFriendView(currentUser: currentUser)
                        .tag(1)
                    
                    ProfileView(passedUserId: currentUser.userId, isUserCurrentlyLogOut: .constant(false), isFromChatView: false)
                        .tag(2)
                }
            }
            ZStack{
                HStack{
                    ForEach((TabItems.allCases), id: \.self){ item in
                        Button{
                            withAnimation(.bouncy) {
                                tabSelection = item.rawValue
                            }
                        } label: {
                            customTabBar(item: item, isActive: tabSelection == item.rawValue)
                        }
                    }
                }
                .padding(6)
            }
            .frame(height: 55)
            .background(.black)
            .cornerRadius(35)
            .padding(.horizontal, 70)
        }
    }
}


extension MainTabView {
    func customTabBar(item:TabItems,isActive:Bool)->some View{
        HStack{
            if #available(iOS 18.0, *) {
                Image(systemName: item.imageName)
                    .tint(isActive ? .white : .gray)
                    .symbolEffect(.wiggle, options: .default, value: tabSelection)
                    .font(.title)
            } else {
                // Fallback on earlier versions
                Image(systemName: item.imageName)
                    .tint(isActive ? .white : .gray)
                    .symbolEffect(.bounce, options: .default, value: tabSelection)
                    .font(.title3)
            }
                
                
//            
//            if isActive{
//                Text(item.Title)
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    
//            }
        }
        .frame(width: isActive ? 100 : 60)
        .frame(height: 40)
        .background(isActive ? .orange : .clear)
        .cornerRadius(30)
        
    }
}

#Preview {
    MainTabView()
}
