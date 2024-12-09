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
    @Published var currentUser:DBUser? = nil
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
    
    
    func getCurrentUser() async{
        guard let user = try? AuthenticationManager.shared.getAuthenticatedUser() else{
            DispatchQueue.main.async {
                self.currentUser =  nil
            }
            return
        }
        guard let dbUser = try? await UserManager.shared.getUser(userId: user.uid) else{
            DispatchQueue.main.async {
                self.currentUser =  nil
            }
            return
        }
        DispatchQueue.main.async {
            self.currentUser =  dbUser
        }
    }
    
    func refresh()async{
        await getCurrentUser()
        await fetchAllUser()
    }
    
    
    func filterUser(){
        let filteredUsers = allUsers.filter { user in
            user.age ?? 18 >= initialAge && user.age ?? 100 <= finalAge
        }
        
        DispatchQueue.main.async {
            
            self.filteredUsers = filteredUsers
        }
    }
    
    
    func fetchAllUser() async {
        let users = await UserManager.shared.getAllUsers()
        DispatchQueue.main.async {
            self.allUsers = users
        }
    }
}

struct FindNewFriendView: View {
    @AppStorage("showExplaination") var showExplaination:Bool = true
    @State var showFilterMenu:Bool = false
    @ObservedObject var vm = FindNewFriendsView()
    @State var gridItem:GridItem = GridItem(.fixed(150))
    @State var otherUser:DBUser? = nil
    @Binding var tabSelection:Int
    
    var body: some View {
        ZStack{
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
                            Button{
                                self.otherUser = otherUser
                            } label: {
                                if let user = vm.currentUser{
                                    OtherUserView(user: user, otherUser: otherUser)
                                        .shadow(radius: 2,y:4)
                                }
                                
                            }
                        }
                    }
                    .padding(.top,20)
                }
                .onAppear{
                    Task{
                        await vm.getCurrentUser()
                        await vm.fetchAllUser()
                        vm.filterUser()
                    }
                }
                .onChange(of: tabSelection, { _, newValue in
                    
                    if newValue == 1{
                        print("run")
                        Task{
                            await vm.getCurrentUser()
                            await vm.fetchAllUser()
                            vm.filterUser()
                        }
                    }
                })//if i use just .onAppear it won't work when the view is swiped because swiftui keep view in memory
                
                .refreshable {
                    await vm.refresh()
                }
                .fullScreenCover(item: $otherUser) { otherUser in
                    ProfileView(passedUserId: otherUser.userId, isUserCurrentlyLogOut: .constant(false), isFromChatView: false, isUser: false, showTabBar: .constant(true), tabSelection: .constant(2))
                }
            }
            if showExplaination{
                explaination
            }
        }
        .foregroundStyle(Color.black)
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
    
    
    private var explaination:some View{
        ZStack{
            
            Color.white.ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showExplaination = false
                    }
                }
            
            VStack{
                HStack{
                    Button {
                        withAnimation {
                            showExplaination = false
                        }
                    } label: {
                        Image(systemName: "x.circle.fill")
                            .font(.title)
                    }
                    .padding()
                    Spacer()
                }
                
                Image(.explainationPic)
                    .resizable()
                    .scaledToFit()
                Spacer()
            }
        }
    }
}


#Preview {
    FindNewFriendView(showFilterMenu: false, tabSelection: .constant(1))
}



