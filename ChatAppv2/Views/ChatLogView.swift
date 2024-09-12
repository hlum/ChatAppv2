//
//  ChatLogView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import SwiftUI
import FirebaseCore
import Firebase




class ChatLogViewModel:ObservableObject{
//    @Published var currentUser:AuthDataResultModel? = AuthenticationManager.shared.currentUser
    @Published var currentUserDB : DBUser? = nil
    @Published var chatMessages:[MessageModel] = []
    private var messagesDictionary : [String:MessageModel] = [:]
    @Published var textFieldText:String = ""
    
    @Published var isLoading : Bool = false
    let recipient : DBUser?
    private var messagesListener:ListenerRegistration?
    
    
    init(recipient: DBUser) {
        self.recipient = recipient
    }
    
    
    @MainActor
    func initialize() async {
        isLoading = true
        defer { isLoading = false }
        
        await fetchCurrentDBUser()
        if currentUserDB != nil {
            fetchMessages()
            markAllMessagesAsRead()
        }
    }
    
    
    func fetchCurrentDBUser() async {
        let currentUser = try? AuthenticationManager.shared.getAuthenticatedUser()
        guard let userId = currentUser?.uid else {
            print("ChatLogView/fetchCurrentDBUser: Can't get currentUserId")
            return
        }
        
        do {
            let user = try await UserManager.shared.getUser(userId: userId)
            await MainActor.run {
                self.currentUserDB = user
            }
            
            self.fetchMessages()
            
        } catch {
            print("Error fetching current user: \(error)")
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
            FirebaseConstants.senderProfileUrl:currentUserDB?.photoUrl ?? "Chat log : No image url",
            FirebaseConstants.senderName : currentUserDB?.name ?? "Can't get sendername messageLogView/sendmessage",
            FirebaseConstants.recieverName:recipient?.name ?? "Can't get recievername messageLogView/sendmessage",
            FirebaseConstants.isUnread : false
        ] as [String : Any]
        
        let message = MessageModel(documentId: "", data: messageData)
        
        await UserManager.shared.storeMessages(message: message)
        DispatchQueue.main.async {
            self.textFieldText = ""
        }
    }
    
    func fetchMessages() {
        guard let fromId = self.currentUserDB?.userId else {
            print("ChatLogViewModel/fetchMessages: Can't get current user id")
            return
        }
        
        
        guard let toId = self.recipient?.userId else {
            print("ChatLogViewModel/fetchMessages: Can't get recipient user id")
            return
        }

        messagesListener = UserManager.shared.getMessages(fromId: fromId, toId: toId) { [weak self] message,changeType in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.handleMessageChanges(message: message, changeType: changeType)
                self.markMessageAsRead(message: message)
            }
        }
    }
    
    func handleMessageChanges(message:MessageModel,changeType:DocumentChangeType){
        let key = message.documentId
        
        switch changeType{
            
        case .added,.modified:
            // just update the dictionary
            messagesDictionary[key] = message
            
        case .removed:
            messagesDictionary.removeValue(forKey: key)
        }
        
        let updateMessages = messagesDictionary.values.sorted {$0.dateCreated.dateValue() < $1.dateCreated.dateValue()}
        
        self.chatMessages = updateMessages
    }
    
    private func markMessageAsRead(message: MessageModel) {
        guard let currentUserId = currentUserDB?.userId,
              message.toId == currentUserId,
              message.isUnread else {
            return
        }

        Task {
            do {
                try await UserManager.shared.markMessageAsRead(userId: currentUserId, chatPartnerId: message.fromId)
            } catch {
                print("Error marking message as read: \(error.localizedDescription)")
            }
        }
    }
    func markAllMessagesAsRead() {
        guard let currentUserId = currentUserDB?.userId,
              let chatPartnerId = recipient?.userId else {
            return
        }

        Task {
            do {
                try await UserManager.shared.markAllMessagesAsRead(userId: currentUserId, chatPartnerId: chatPartnerId)
            } catch {
                print("Error marking all messages as read: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelListeners() {
        messagesListener?.remove()
    }

    deinit {
        cancelListeners()
    }
}





struct ChatLogView:View {
    @StateObject var vm : ChatLogViewModel
    init(recipient: DBUser) {
            _vm = StateObject(wrappedValue: ChatLogViewModel(recipient: recipient))
        }
    
    var body : some View{
        VStack{
            if vm.isLoading {
                ProgressView()
            } else {
                MessagesView
                ChatBottomBar
            }

        }
        .task {
            await vm.initialize()
        }

        .onDisappear {
            vm.cancelListeners()
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
            if let currentUser = AuthenticationManager.shared.currentUser {
                if chatMessage.fromId == currentUser.uid{
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
}
