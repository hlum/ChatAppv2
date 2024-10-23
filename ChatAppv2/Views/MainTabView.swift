//
//  MainTabView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 9/26/24.
//

import SwiftUI
import SDWebImageSwiftUI

class MainTabViewModel:ObservableObject{
    @Published var isUserCurrentlyLoggedOut:Bool = false
    @Published var user:DBUser? = nil

    init(){
        Task{
            let isUserCurrentlyLoggedOut = await !checkTheUserIsInDataBase()
            DispatchQueue.main.async {
                self.isUserCurrentlyLoggedOut = isUserCurrentlyLoggedOut
            }

           await fetchCurrentUser()
        }
    }
    
    func checkTheUserIsInDataBase() async -> Bool {
           guard let user = try? AuthenticationManager.shared.getAuthenticatedUser()else{
               print("Can't get current user")
               return false
           }
           do {
               return try await UserManager.shared.checkIfUserExistInDatabase(userId: user.uid)
           } catch {
               return false
           }
       }

    
    func fetchCurrentUser()async{
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
            "person.2.fill"
        case .ProfileView:
            "person.circle.fill"
        }
    }
}

struct MainTabView: View {
    @Namespace var nameSpace
    @StateObject var vm = MainTabViewModel()
    @State var showTabBar:Bool = true
    
    @State var tabSelection: Int = 0
    var body: some View {
            ZStack(alignment:.bottom){
                TabView (selection:$tabSelection){
                    RecentMessagesView(isUserCurrentlyLoggedOut: $vm.isUserCurrentlyLoggedOut, tabSelection: $tabSelection)
                        .tag(0)
                    if let currentUser = vm.user{
                        FindNewFriendView( tabSelection: $tabSelection)
                            .tag(1)
                        
                        ProfileView(passedUserId: currentUser.userId, isUserCurrentlyLogOut: $vm.isUserCurrentlyLoggedOut, isFromChatView: false, isUser: true, showTabBar: $showTabBar, tabSelection: $tabSelection)
                            .tag(2)
                    }
                }
                .task {
                    await vm.fetchCurrentUser()
                }
                .tabViewStyle(.page(indexDisplayMode: .never))  
                if showTabBar{
                    tabBar
                }
            }
            .onChange(of: tabSelection, { _, newValue in
                print(newValue)
            })
            .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut, onDismiss: {
                Task{
                    await vm.fetchCurrentUser()
                }
            }, content: {
                OnboardingView(isUserCurrentlyLoggedOut: $vm.isUserCurrentlyLoggedOut)
            })
            .ignoresSafeArea(edges:.bottom)
        
        
    }
}


extension MainTabView {
    private var tabBar:some View{
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
        .background(.thinMaterial)
        .cornerRadius(35)
        .padding(.horizontal, 70)
        .ignoresSafeArea()
        .padding(.bottom,40)

    }
    func customTabBar(item:TabItems,isActive:Bool)->some View{
        ZStack{
            if isActive{
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.orange)
                    .frame(width:100,height:40)
                    .matchedGeometryEffect(id: "TabItemId", in: nameSpace)
            }
            HStack{
                if #available(iOS 17.0, *) {
                    Image(systemName: item.imageName)
                        .tint(isActive ? .white : .gray)
                        .symbolEffect(.bounce, options: .default, value: tabSelection)
                        .font(.title)
                } else {
                    // Fallback on earlier versions
                    Image(systemName: item.imageName)
                        .tint(isActive ? .white : .gray)
                        .font(.title3)
                }
                
            }
            .frame(width: isActive ? 100 : 60)
            .frame(height: 40)
//            .background(isActive ? .orange : .clear)
            .cornerRadius(30)
        }
    }
}

#Preview {
    MainTabView()
}
