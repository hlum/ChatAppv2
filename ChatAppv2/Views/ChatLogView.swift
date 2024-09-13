//
//  ChatLogView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import SwiftUI
import FirebaseCore
import Firebase
import SDWebImageSwiftUI



class ChatLogViewModel: ObservableObject {
    @Published var currentUserDB: DBUser? = nil
    @Published var chatMessages: [MessageModel] = []
    
    @Published var lastReadMessageId: String? = nil
    private var messagesDictionary: [String: MessageModel] = [:]
    
    @Published var textFieldText: String = ""
    
    let recipient: DBUser?
    
    
    private var messagesListener: ListenerRegistration?
    private var lastReadListener: ListenerRegistration?
    
    @Published var isLoading: Bool = false
    
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
            fetchLastReadMessage()
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
        
        let message = MessageModel(documentId: "",id:"" , data: messageData)
        
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
    
    func markMessageAsRead(message: MessageModel) {
        guard let currentUserId = currentUserDB?.userId,
              message.toId == currentUserId,
              message.isUnread else {
            return
        }

        Task {
            do {
                try await UserManager.shared.markMessageAsRead(userId: currentUserId, chatPartnerId: message.fromId, messageId: message.documentId)
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
    
    func fetchLastReadMessage() {
         guard let currentUserId = currentUserDB?.userId,
               let recipientId = recipient?.userId else {
             return
         }
         
         lastReadListener = UserManager.shared.getLastReadMessage(userId: recipientId, chatPartnerId: currentUserId) { [weak self] lastReadMessageId in
             DispatchQueue.main.async {
                 self?.lastReadMessageId = lastReadMessageId
             }
         }
     }

    
    func cancelListeners() {
        messagesListener?.remove()
        lastReadListener?.remove()
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
                messagesView
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
    
    private var messagesView: some View {
        ScrollView {
            ScrollViewReader { scrollViewProxy in
                LazyVStack {
                    ForEach(vm.chatMessages) { message in
                        MessageView(message: message, isFromCurrentUser: message.fromId == vm.currentUserDB?.userId)
                        HStack{
                            Spacer()
                            if message.documentId == vm.lastReadMessageId &&
                                message.fromId == vm.currentUserDB?.userId
                            {
                                WebImage(url: URL(string: vm.recipient?.photoUrl ?? ""))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 15, height: 15)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                    .offset(x: 10, y: 10)
                                    .padding()
                            }
                        }
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
        }
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





struct MessageView: View {
    let message: MessageModel
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            Text(message.text)
                .padding()
                .background(isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isFromCurrentUser ? .white : .black)
                .cornerRadius(10)
            
            if !isFromCurrentUser { Spacer() }
        }
        .padding(.horizontal)
    }
}
