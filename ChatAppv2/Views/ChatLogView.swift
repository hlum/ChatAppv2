//
//  ChatLogView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import SwiftUI
import FirebaseCore




class ChatLogViewModel:ObservableObject{
//    @Published var currentUser:AuthDataResultModel? = AuthenticationManager.shared.currentUser
    @Published var currentUserDB : DBUser? = nil
    @Published var chatMessages:[MessageModel] = []
    @Published var textFieldText:String = ""
    let recipient : DBUser?
    init(recipient: DBUser) {
        self.recipient = recipient
        fetchCurrentDBUser { user in
            if user != nil{
                self.fetchMessages()
            }else{
                print("ChatlogViewModel/init:NO user found")
            }
        }
        
    }
    func fetchCurrentDBUser(completion:@escaping(DBUser?)->()){
        let currentUser =  try? AuthenticationManager.shared.getAuthenticatedUser()
        guard let userId = currentUser?.uid else{
            print("ChatLogView/fetchCurrentDBUser:Can't get currentUserId")
            return
        }
        Task{
    
                let user = try? await UserManager.shared.getUser(userId: userId)
                DispatchQueue.main.async{
                    self.currentUserDB = user
                    completion(user)
                }
            
    }
        
    }
    
    
    func sendMessage() async{
        guard let fromId = self.currentUserDB?.userId
            else{
                print("Can't get current user id")
                return
            }
        guard let toId = self.recipient?.userId
            else{
                print("Can't get recipient user id")
                return
            }

        //data for the sender
        let messageData = [
            FirebaseConstants.fromId: fromId,
            FirebaseConstants.toId: toId,
            FirebaseConstants.text: self.textFieldText,
            FirebaseConstants.dateCreated: Timestamp(),
            FirebaseConstants.recipientProfileUrl:recipient?.photoUrl ?? "",
            FirebaseConstants.recipientEmail : recipient?.email ?? "",
            FirebaseConstants.senderEmail : currentUserDB?.email ?? "",
            FirebaseConstants.senderProfileUrl:currentUserDB?.photoUrl ?? "Chat log : No image url"
        ] as [String : Any]
        
        let message = MessageModel(documentId: "", data: messageData)
        
        await UserManager.shared.storeMessages(message: message)
        DispatchQueue.main.async {
            self.textFieldText = ""
        }
    }
    
    func fetchMessages() {
        guard let fromId = self.currentUserDB?.userId else{
            print("ChatLogViewModel/fetchMessages : Can't get current user id")
            return
        }
        
        UserManager.shared.getMessages(fromId: fromId, toId: recipient?.userId) { [weak self] message in
            DispatchQueue.main.async {
                self?.chatMessages.append(message)
            }
        }
    }
}





struct ChatLogView:View {
    @ObservedObject var vm : ChatLogViewModel
    init(recipient:DBUser){
        self.vm = ChatLogViewModel(recipient: recipient)
    }
    
    var body : some View{
        VStack{
            MessagesView
                
            ChatBottomBar

        }
        .navigationTitle(vm.recipient?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension ChatLogView{
    
    private var MessagesView:some View{
        ScrollView{
            ScrollViewReader { scrollViewProxy in
                ForEach(vm.chatMessages){chatMessage in
                    MessageBubbleView(chatMessage:chatMessage)
                }
                HStack{ Spacer() }
                    .id("Empty")
                    .onChange(of: vm.chatMessages.count) { _ , _ in
                        // Scroll to the bottom whenever a new message is added
                        withAnimation {
                            scrollViewProxy.scrollTo("Empty", anchor: .bottom)
                        }
                    }
            }
        }
        .padding(.bottom,20)
        .background(Color(.init(white:0.95,alpha:1)))
        
    }
    
    private var ChatBottomBar: some View{
        HStack(spacing:16){
            Image(systemName: "photo.on.rectangle")
                .font(.title)
            TextField("Description.....", text: $vm.textFieldText,axis: .vertical)
            Button {
                Task{
                    await vm.sendMessage()
                }
                
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 30))
            }
            .disabled(vm.textFieldText.isEmpty)
            .padding(.horizontal)

        }
        .frame(height: 40)
        .padding(.horizontal)
    }
}





struct MessageBubbleView :View {
    let chatMessage:MessageModel
    var body: some View {
        VStack{
            if chatMessage.fromId == AuthenticationManager.shared.currentUser?.uid{
                HStack{
                    Spacer()
                    HStack{
                        Text(chatMessage.text)
                            .foregroundStyle(Color(.white))
                    }
                    .padding()
                    .background(.blue)
                    .cornerRadius(10)
                    .padding(.bottom,1)

                }
                .padding(.horizontal)
            }else{
                HStack{
                    HStack{
                        Text(chatMessage.text)
                            .foregroundStyle(Color(.black))
                    }
                    .padding()
                    .background(.white)
                    .cornerRadius(10)
                    .padding(.bottom,1)

                    Spacer()
                }
                .padding(.horizontal)

            }
        }
    }
}
