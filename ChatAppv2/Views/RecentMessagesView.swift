
import SwiftUI
import Firebase
import SDWebImageSwiftUI

class MainViewMessageViewModel:ObservableObject{
    @Published var showLogOutOption : Bool = false
    @Published var currentUserDB : DBUser? = nil // currentUser
    @Published var isUserCurrentlyLoggedOut:Bool = true
    @Published var showFindNewFriendView:Bool = false
    @Published var recentMessages: [MessageModel] = []
    
    
    @Published var isLoading:Bool = false
    @Published var progress:Float = 0.0 //from 0 -> 1
    
    

    
    private var messagesListener:ListenerRegistration?
    private var lastReadMessageIdListener:ListenerRegistration?

    
    
    init(){
        self.isUserCurrentlyLoggedOut = !AuthenticationManager.shared.checkIfUserIsAuthenticated()

    }
    
    func fetchUserData()async {
        await handledLoading(progress: 0.1)
        guard let authDataResult = try? AuthenticationManager.shared.getAuthenticatedUser()else {
            print("MainViewMessageViewModel:Can't fetch user data")
            isUserCurrentlyLoggedOut = true
            return
        }
        await handledLoading(progress: 0.15)

            let user = try? await UserManager.shared.getUser(userId: authDataResult.uid)
        
        await handledLoading(progress: 0.3)

            DispatchQueue.main.async{
                
                self.currentUserDB = user
            }
        await handledLoading(progress: 1)

    }
    
    func logOut(){
        AuthenticationManager.shared.signOut()
        self.recentMessages = []
        self.currentUserDB = nil
    }
    
    
    func fetchRecentMessages() {
        guard let userId = try? AuthenticationManager.shared.getAuthenticatedUser().uid else {
            isUserCurrentlyLoggedOut = true
            return
        }
        messagesListener = ChatManager.shared.recentMessagesCollection
            .document(userId)
            .collection("messages")
            .order(by: FirebaseConstants.dateCreated, descending: true)  // Use timestamp and descending order
            .addSnapshotListener { [weak self] querySnapshot, error in
                
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching recent messages: \(error.localizedDescription)")
                    return
                }
                
                guard let changes = querySnapshot?.documentChanges else { return }
                
                for change in changes {
                    let docId = change.document.documentID
                    let messageData = change.document.data()
                    var recentMessage = MessageModel(documentId: docId, data: messageData)
                    
                    if change.type == .removed {
                        self.recentMessages.removeAll { $0.documentId == docId }
                        continue
                    }
                    
                    if recentMessage.toId == userId {
                        // Message is to the current user
                        self.handleIncomingMessage(userId:userId,recentMessage, messageData: messageData)
                    } else {
                        // Message is from the current user
                        recentMessage.isRead = true
                        self.updateOrInsertMessage(recentMessage)
                    }
                }
            }
    }

    // Handle incoming message
    private func handleIncomingMessage(userId:String,_ recentMessage: MessageModel, messageData: [String: Any]) {
        self.lastReadMessageIdListener = ChatManager.shared.getLastReadMessageId(userId: userId, chatPartnerId: recentMessage.fromId) { [weak self] _, chatPartnerLastReadMessageId in
            guard let self = self else { return }
            
            var updatedMessage = recentMessage
            if messageData["document_id"] as? String ?? "" == chatPartnerLastReadMessageId {
                updatedMessage.isRead = true
            } else {
                updatedMessage.isRead = false
            }
            Task{
                await self.handledLoading(progress: 0.8)
            }

            self.updateOrInsertMessage(updatedMessage)
        }
    }

    private func updateOrInsertMessage(_ message: MessageModel) {
        if let index = self.recentMessages.firstIndex(where: { $0.documentId == message.documentId }) {
            self.recentMessages.remove(at: index)
        }
        
        // Find the correct position to insert the message based on timestamp
        let insertionIndex = self.recentMessages.firstIndex(where: {
            $0.dateCreated.dateValue() < message.dateCreated.dateValue()
        }) ?? self.recentMessages.endIndex
        
        
        self.recentMessages.insert(message, at: insertionIndex)
        Task{
            await handledLoading(progress: 1)
        }
    }
    
    @MainActor
    private func handledLoading(progress: Float) {
        self.progress = progress
        self.isLoading = progress < 1
    }
    
    @MainActor
    func refreshData() async {
        // Cancel existing listeners
        messagesListener?.remove()

        // Fetch user data
        await fetchUserData()

        // Fetch recent messages
        fetchRecentMessages()
    }
    
    func cancelListeners() {
        messagesListener?.remove()
        lastReadMessageIdListener?.remove()
    }
    
    deinit {
        cancelListeners()
    }
}


struct RecentMessagesView: View {
    @StateObject var vm = MainViewMessageViewModel()
    var body: some View {
        NavigationStack{
            
            ZStack{
                VStack{
                    NavigationLink {
                        ProfileView(passedUserId: vm.currentUserDB?.userId ?? "", isUserCurrentlyLogOut: $vm.isUserCurrentlyLoggedOut, isFromChatView: false)
                    } label: {
                        customNavBar
                            .foregroundStyle(Color(.black))
                    }
                    ZStack{
                        ScrollView{
                            messagesView
                                .refreshable {
                                    await vm.refreshData()
                                }
                        }
                        if vm.recentMessages.isEmpty{
                            VStack{
                                Image(systemName: "plus.message.fill")
                                    .font(.system(size: 100))
                                    .foregroundStyle(Color.gray)
                                    .padding()
                                
                                Text("誰かに話しかけてみませんか？")
                                    .font(.headline)
                                    .foregroundStyle(Color.gray)
                            }
                            
                        }
                    }
                    .onTapGesture {
                        if let currentUser = vm.currentUserDB{
                            vm.showFindNewFriendView = true
                        }
                    }

                    
                }
                .onAppear(perform: {
                    
                    Task{
                        await vm.fetchUserData()
                        vm.fetchRecentMessages()
                    }
                })
                .onDisappear {
                          vm.cancelListeners()
                      }
                
                .overlay(newMessageButton,alignment: .bottom)
                .toolbar(.hidden)
                
                if vm.isLoading {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                        
                        ProgressView(value: vm.progress)
                            .frame(width: 200)
                            .tint(.white)
                            .padding()
                        
                        Text("\(Int(vm.progress * 100))%")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }

            }//End of ZStack
        }//End of NavigationStack
    }
}

//MARKS: View extensions

extension RecentMessagesView{
    
    
    private var customNavBar:some View{
        HStack{
            
            if let currentUser = vm.currentUserDB ,
               let urlString = currentUser.photoUrl
            {
                WebImage(url: URL(string: urlString)) { image in
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
                        Image(.profilePic)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60,height: 60)
                            .padding()
                    }
            }


            VStack(alignment:.leading,spacing: 4){
                let name = vm.currentUserDB?.name ?? "........"
                Text(name)
                    .font(.system(size: 24,weight:.bold))
                
                HStack{
                    Circle()
                        .foregroundStyle(Color(.green))
                        .frame(width: 14)
                    Text("online")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.lightGray))
                }
            }
            
            Spacer()
            Button {
                vm.showLogOutOption.toggle()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 24,weight:.bold))
                    .foregroundStyle(Color(.label))
            }
        }
        .padding()
        .actionSheet(isPresented: $vm.showLogOutOption) {
            .init(title: Text("Settings"), message: Text("What do you want to do?"), buttons: [
                .destructive(Text("Sign Out"),action: {
                    vm.logOut()
                    vm.isUserCurrentlyLoggedOut = !AuthenticationManager.shared.checkIfUserIsAuthenticated()
                }),
                .cancel()
                
            ])
        }
        .fullScreenCover(isPresented:$vm.isUserCurrentlyLoggedOut,onDismiss: {
            Task{
                await vm.fetchUserData()
                vm.fetchRecentMessages()
            }
        })  {
            OnboardingView(isUserCurrentlyLoggedOut:$vm.isUserCurrentlyLoggedOut)
        }
    }
    
    
   // MARKS : messagesView
    private var messagesView:some View{
        ForEach(vm.recentMessages) { recentMessage in
            
            VStack{
                
                NavigationLink {
                    ChatLogView(recipient:  DBUser(recentMessage: recentMessage, currentUser: vm.currentUserDB ?? DBUser(userId:"")))
                } label: {
                    HStack(spacing: 10){
                        WebImage(url: URL(string: recentMessage.recipientProfileUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width:65,height: 65)
                                .cornerRadius(65)
                                .overlay(RoundedRectangle(cornerRadius: 44)
                                    .stroke(Color(.label),lineWidth: 1)
                                )
                                .padding()
                            
                            
                        } placeholder: {
                            Image(.profilePic)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 65,height: 65)
                                .padding()
                            
                        }
                        
                        VStack(alignment:.leading){
                            
                            Text(recentMessage.recieverName)
                                .font(.system(size: 16,weight: .bold))
                            
                            
                            
                            Text(recentMessage.text)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(.lightGray))
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(recentMessage.formattedTime)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                            
                            // add an unread message indicator here if needed
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 10, height: 10)
                                .opacity(recentMessage.isRead ? 0 : 1)
                        }
                        .padding(.trailing)
                    }
                }
                .foregroundStyle(Color(.label))
                Divider()
                    .padding(.vertical,8)
            }
            .padding(.horizontal)
        }
}
    
    private var newMessageButton:some View{
        Button {
            vm.showFindNewFriendView = true
        } label: {
            HStack{
                Spacer()
                Text("友達を探す")
                    .font(.system(size: 16,weight: .bold))
                Spacer()
            }
            .foregroundStyle(Color(.white))
            .padding(.vertical)
            .background(.blue)
            .cornerRadius(32)
            .padding()
            .shadow(radius: 15)
        }
        .fullScreenCover(isPresented: $vm.showFindNewFriendView) {
            if let currentUser = vm.currentUserDB{
                FindNewFriendView(currentUser: currentUser)
            }
        }
    }
}
