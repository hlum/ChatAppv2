//
//  NewMessageView.swift
//  MessageApp
//
//  Created by Hlwan Aung Phyo on 8/29/24.
//

import SwiftUI
import Firebase
import FirebaseAuth

class CreateNewMessageViewModel: ObservableObject{
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



struct CreateNewMessageView: View {
    @ObservedObject var vm = CreateNewMessageViewModel()
    @Environment(\.dismiss) var dismiss
    
    let selectedNewUser:(DBUser) -> ()
    
    var body: some View {
        NavigationView{
            ScrollView {
                Text(vm.errorMessage)
                ForEach(vm.users){user in
                        Button {
                            dismiss()
                            selectedNewUser(user)
                        } label: {
                            HStack(spacing: 16){
                                AsyncImage(url: URL(string:user.photoUrl ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width:50,height: 50)
                                        .clipped()
                                        .cornerRadius(50)
                                        .overlay(RoundedRectangle(cornerRadius: 44)
                                            .stroke(Color(.label),lineWidth: 1)
                                        )
                                        .shadow(radius: 5)

                                } placeholder: {
                                    ProgressView()
                                        .frame(width:50,height: 50)
                                }
                                
                                Text(user.email ?? "")
                                
                                Spacer()
                            }
                            .padding(.horizontal)

                        }
                    

                                       
                    Divider()
                        .padding(.vertical,8)
                    
                }
            }
            .navigationTitle("New Message")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }

                }
            }
        }
    }
}

#Preview {
    CreateNewMessageView(selectedNewUser: {user in
        
    })
}
