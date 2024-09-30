//
//  NewMessageView.swift
//  MessageApp
//
//  Created by Hlwan Aung Phyo on 8/29/24.
//

import SwiftUI
import Firebase
import FirebaseAuth

final class FindNewFriendsView: ObservableObject{
    @Published var allUsers: [DBUser] = []
    @Published var filteredUsers: [DBUser] = []
    @Published var errorMessage = ""
    @Published var initialAge:Double = 18{
        didSet{
            filterUser()
        }
    }
    @Published var finalAge:Double = 100{
        didSet{
            filterUser()
        }
    }
    
    init(){
        Task{
            await fetchAllUser()
            filterUser()
        }
    }
    
    
    func filterUser(){
        let filteredUsers = allUsers.filter { user in
            user.age ?? 0.0 >= initialAge && user.age ?? 0.0 <= finalAge
        }
        
        DispatchQueue.main.async {
            self.filteredUsers = filteredUsers
        }
    }
    private func fetchAllUser() async {
        let users = await UserManager.shared.getAllUsers()
        DispatchQueue.main.async {
            self.allUsers = users
        }
    }
}

struct FindNewFriendView: View {
    
    @State var showFilterMenu:Bool = false
    var currentUser:DBUser
    @ObservedObject var vm = FindNewFriendsView()
    @Environment(\.presentationMode) var presentationMode
    @State var gridItem:GridItem = GridItem(.fixed(150))
    
    var body: some View {
        NavigationStack{
            VStack(spacing:0){
                customHeader
                    if showFilterMenu{
                        VStack{
                            Text("\(Int(vm.initialAge))歳 から \(Int(vm.finalAge))歳")
                            AgeRangeView(initialAge: $vm.initialAge, finalAge: $vm.finalAge)
                        }
                        .transition(.move(edge: .top))
                            
                    }
                    ScrollView(.vertical,showsIndicators: false) {
                            LazyVGrid(columns: [gridItem,gridItem]) {
                                ForEach(showFilterMenu ? vm.filteredUsers : vm.allUsers) { otherUser in
                                    NavigationLink {
                                        ProfileView(passedUserId: otherUser.userId, isUserCurrentlyLogOut: .constant(false), isFromChatView: false)
                                    } label: {
                                        OtherUserView(user: currentUser, otherUser: otherUser)
                                            .shadow(radius: 2,y:4)
                                    }
                                }
                            }
                        .padding(.top,20)
                    }
                
            }
        }
    }
}

extension FindNewFriendView{
    private var customHeader:some View{
        HStack{
              Text("友達を探す")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.leading)
            
            Spacer()
            
            Button {
                vm.filterUser()
                showFilterMenu.toggle()
                
            } label: {
                Image(systemName: "line.3.horizontal.circle")
                    .font(.title)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .frame(height: 55)
        
    }
}
