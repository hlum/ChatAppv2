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
    
    @Published var lastReadMessageId: String = ""
    private var messagesDictionary: [String: MessageModel] = [:]
    
    @Published var textFieldText: String = ""
    let recipient: DBUser?

    private var messagesListener: ListenerRegistration?
    private var listenerToLastReadMessageId: ListenerRegistration?

    @Published var isLoading: Bool = false
    
    private var lastUpdateTimestamp: TimeInterval = 0
    
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    

    init(recipient: DBUser) {
        self.recipient = recipient
    }

    @MainActor
    func initialize() async {
        isLoading = true

        await fetchCurrentDBUser()
        if currentUserDB != nil {
            fetchMessages()
            startListeningToLastReadMessageId()
            

            Task {
                await waitForMessages()
                updateLastReadMessageId()
            }
            isLoading = false
        }
    }

    func waitForMessages() async {
        // This loop waits until the chatMessages array is populated
        while chatMessages.isEmpty {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }
    }
    
    
    func fetchCurrentDBUser() async {
        guard let currentUser = try? AuthenticationManager.shared.getAuthenticatedUser() else{
            print("ChatLogView/fetchCurrentDBUser: Can't get currentUser")
            return
        }
        let userId = currentUser.uid
        
        do {
            let user = try await UserManager.shared.getUser(userId: userId)
            await MainActor.run {
                self.currentUserDB = user
            }
            
        } catch {
            print("Error fetching current user: \(error)")
        }
    }

    func sendMessage2() async{
        guard let fromId = self.currentUserDB?.userId else {
            print("ChatLogViewModel/fetchMessages: Can't get current user id")
            return
        }
        
        
        guard let toId = self.recipient?.userId else {
            print("ChatLogViewModel/fetchMessages: Can't get recipient user id")
            return
        }
        
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
            FirebaseConstants.recieverName:recipient?.name ?? "Can't get recievername messageLogView/sendmessage"
        ] as [String : Any]
        
        let message = MessageModel(documentId: "",id:"" , data: messageData)
        
        await ChatManager.shared.sendMessage(message: message, recipientId: toId, userId: fromId)
        DispatchQueue.main.async {
            self.textFieldText = ""
        }
        
    }

    
    func fetchMessages(){
        guard let fromId = self.currentUserDB?.userId else {
            print("ChatLogViewModel/fetchMessages: Can't get current user id")
            return
        }
        
        
        guard let toId = self.recipient?.userId else {
            print("ChatLogViewModel/fetchMessages: Can't get recipient user id")
            return
        }
        
        ChatManager.shared.getMessages(userId: fromId, recipientId: toId) {[weak self] message, changeType in
            guard let self = self else {return}
            
            DispatchQueue.main.async {
                self.handleMessageChanges(message: message, changeType: changeType)
            }
        }
    }
    
    @MainActor
    func showAlert(alertTitle:String){
        self.alertTitle = alertTitle
        showAlert = true
    }
    
    @MainActor
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

    func updateLastReadMessageId() {
        guard let userId = currentUserDB?.userId,
              let chatPartnerId = recipient?.userId else {
            print("Can't get the userId or chatPartnerId")
            return
        }
        guard !chatMessages.isEmpty else {
            print("No chatMessages found")
            return
        }

        let now = Date().timeIntervalSince1970
        // Only update if more than 1 second has passed since the last update
        if now - lastUpdateTimestamp > 0.009 {
            lastUpdateTimestamp = now
            Task {
                await ChatManager.shared.updateLastReadMessageId(userId: userId, chatPartnerId: chatPartnerId, lastMessageId: chatMessages.last?.documentId ?? "")
            }
        }
    }
    
    
    @MainActor
    func startListeningToLastReadMessageId() {
         guard let currentUserId = currentUserDB?.userId,
               let recipientId = recipient?.userId else {
             return
         }
         
    
        self.listenerToLastReadMessageId = ChatManager.shared.getLastReadMessageId(userId: currentUserId, chatPartnerId: recipientId, completion: { lastReadMessageId,_  in
            DispatchQueue.main.async {
                self.lastReadMessageId = lastReadMessageId
            }
        })
     }

    
    func cancelListeners() {
        messagesListener?.remove()
        listenerToLastReadMessageId?.remove()
    }

    deinit {
        cancelListeners()
    }
}





struct ChatLogView:View {
    @StateObject var vm : ChatLogViewModel
    @FocusState var isFocused: Bool
    @Environment(\.presentationMode) var presentationMode
    @State var isShowingProfile = false

    init(recipient: DBUser) {
            _vm = StateObject(wrappedValue: ChatLogViewModel(recipient: recipient))
        }
    
    var body : some View{
        ZStack{
            VStack(spacing:0){
                if vm.isLoading {
                    ProgressView()
                } else {
                    
                    messagesView
                        .padding(.bottom,20)
                        .onTapGesture {
                            isFocused.toggle()
                        }
                    
                    
                    ChatBottomBar
                }
                
            }
            .alert(isPresented: $vm.showAlert) {
                Alert(title: Text(vm.alertTitle))
            }
            .background(.white)
            .safeAreaInset(edge: .top) {
                if !vm.isLoading{
                    Button{
                        isShowingProfile = true
                    } label: {
                        customNavBar
                            .shadow(color: Color.black.opacity(0.1), radius: 9, x: 0,y:1)
                    }
                    .foregroundStyle(Color(.label))
                }
            }
            .fullScreenCover(isPresented: $isShowingProfile) {
                ProfileView(passedUserId: vm.recipient?.userId ?? "", isUserCurrentlyLogOut: .constant(false), isFromChatView: true, isUser: false, showTabBar: .constant(true), tabSelection: .constant(2))
            }
            
            .task {
                await vm.initialize()
            }
            
            .onDisappear {
                vm.cancelListeners()
            }
            .toolbar(.hidden)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

extension ChatLogView{
    private var customNavBar: some View {
        HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.title3)
                            .padding()
                            .padding(.bottom)
                    }
                    
                    if let recipient = vm.recipient,
                       let photoUrl = recipient.photoUrl
                    {
                        WebImage(url: URL(string: photoUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipped()
                                .cornerRadius(50)
                                .overlay(RoundedRectangle(cornerRadius: 44)
                                    .stroke(Color(.label), lineWidth: 1)
                                )
                                .padding(.trailing)
                                .padding(.bottom)
                        } placeholder: {
                            Image(.profilePic)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .padding(.trailing)
                                .padding(.bottom)

                        }
                    } else {
                        Image(.profilePic)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .padding(.trailing)
                            .padding(.bottom)
                    }
                    
                    VStack(alignment:.leading){
                        if let recipient = vm.recipient {
                            Text(recipient.name ?? "")
                                .font(.title3)
                                .fontWeight(.semibold)
                            if let email = recipient.email{
                                let studentId = email
                                                .replacingOccurrences(of: "@jec.ac.jp", with: "")
                                                .replacingOccurrences(of: "@gmail.com", with: "")
                                                                            
                                Text(studentId)
                                    .font(.subheadline)
                                    .foregroundStyle(Color(.lightGray))
                            }
                        }
                    }
                    .padding(.bottom)
                    Spacer()
                }
                .background(.white)
    }

    
    private var messagesView: some View {
        ScrollView {
            ScrollViewReader { scrollViewProxy in
                LazyVStack {
                    ForEach(vm.chatMessages) { message in
                        MessageView(message: message, isFromCurrentUser: message.fromId == vm.currentUserDB?.userId)
                        
                        // Check if this is the last message and show the last-read indicator
                        if message.documentId == vm.lastReadMessageId &&
                           message.fromId == vm.currentUserDB?.userId {
                            HStack {
                                Spacer()
                                WebImage(url: URL(string: vm.recipient?.photoUrl ?? ""))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 15, height: 15)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                    .offset(x: 10, y: 10)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    // Spacer to push content upwards
                    HStack {
                        Spacer()
                    }
                    .padding(.bottom)
                    .id("Empty") // This id ensures scrolling to the bottom
                }
                .onChange(of: vm.chatMessages.count) { _, _ in
                    // Scroll to the bottom whenever the message count changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // slight delay
                        vm.updateLastReadMessageId()
                        withAnimation {
                            scrollViewProxy.scrollTo("Empty", anchor: .bottom)
                        }
                    }
                }
                // Scroll on appear as well to ensure we start from the bottom
                
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // slight delay
                        if !vm.chatMessages.isEmpty {
                            scrollViewProxy.scrollTo("Empty", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private var ChatBottomBar: some View{
        HStack(spacing:16){
            TextField("Description.....", text: $vm.textFieldText,axis: .vertical)
                .submitLabel(.return)
                .focused($isFocused)

            Button {
                if vm.textFieldText.count >= 60{
                    vm.showAlert(alertTitle: "メッセージは60文字以下で入力してください")
                }else{
                    Task{
                        await vm.sendMessage2()
                    }
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




