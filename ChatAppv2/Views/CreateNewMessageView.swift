//
//  NewMessageView.swift
//  MessageApp
//
//  Created by Hlwan Aung Phyo on 8/29/24.
//

import SwiftUI
import Firebase
import FirebaseAuth

final class CreateNewMessageViewModel: ObservableObject{
    @Published var users: [DBUser] = []
    @Published var errorMessage = ""
    
    init(){
        Task{
            await fetchAllUser()
        }
    }
    
    private func fetchAllUser() async {
        let users = await UserManager.shared.getAllUsers()
        DispatchQueue.main.async {
            self.users = users
        }
    }
}

enum filterOptions{
    case age
}

struct CreateNewMessageView: View {
    @State var showFilterMenu:Bool = false
    var currentUser:DBUser
    @ObservedObject var vm = CreateNewMessageViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State var gridItem:GridItem = GridItem(.fixed(150))
    
    var body: some View {
        VStack(spacing:0){
            customHeader
            ScrollView(.vertical,showsIndicators: false) {
                LazyVGrid(columns: [gridItem,gridItem]) {
                    ForEach(vm.users) { otherUser in
                        OtherUserView(user: currentUser, otherUser: otherUser)
                    }
                }
                .padding(.top,20)
            }
        }
    }
}

extension CreateNewMessageView{
    private var customHeader:some View{
        HStack{
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            Spacer()
            Text("友達を探す")
                .font(.title3)
                .fontWeight(.bold)
            
            Spacer()
            
            Button {
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
