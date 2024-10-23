
import SwiftUI
import Firebase
import SDWebImageSwiftUI

class MainViewMessageViewModel:ObservableObject{
    @Published var showLogOutOption : Bool = false
    @Published var currentUserDB : DBUser? = nil // currentUser
    @Published var recentMessages: [MessageModel] = []
    @Published var wantToTalk:WantToTalk = .Three
    
    
    @Published var isLoading:Bool = false
    @Published var progress:Float = 0.0 //from 0 -> 1
    
    @Published var showAlert:Bool = false
    @Published var alertMessage:String = ""
    
    

    
    private var messagesListener:ListenerRegistration?
    private var lastReadMessageIdListener:ListenerRegistration?

    
    
    init(){
        Task{
            await fetchUserData()
            fetchRecentMessages()
        }
    }
    
    func updateUserWantToTalkStatus() async{
        guard
            let user = try? AuthenticationManager.shared.getAuthenticatedUser()
        else {
            print("Can't get userId")
            return
        }
        try? await UserManager.shared.updateUserWantedToTalk(userId: user.uid, newWantedToTalk: wantToTalk)
    }
    
    
    func showMessage(alertMessage:String){
        showAlert = true
        self.alertMessage = alertMessage
    }
    func fetchUserData()async {
        await handledLoading(progress: 0.1)
        guard let authDataResult = try? AuthenticationManager.shared.getAuthenticatedUser()else {
            print("MainViewMessageViewModel:Can't fetch user data")
            return
        }


            let user = try? await UserManager.shared.getUser(userId: authDataResult.uid)
        
        await handledLoading(progress: 0.9)

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
    @AppStorage("showButtonExplaination") var showButtonExplaination:Bool = true
    @Namespace var nameSpace
    @State var showWantToTalkMenu :Bool = false
    @Binding var isUserCurrentlyLoggedOut :Bool
    @Binding var tabSelection : Int
    @StateObject var vm = MainViewMessageViewModel()
    @State var recentMessage:MessageModel? = nil
    var body: some View {
        NavigationStack{
            ZStack{
                VStack{
                    customNavBar
                        .foregroundStyle(Color(.black))
                    ZStack{
                        ScrollView{
                            messagesView
                        }
                        .refreshable {
                            await vm.refreshData()
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
                            .onTapGesture {
                                if let _ = vm.currentUserDB{
                                    tabSelection = 1
                                    print("Clicked")
                                }
                                
                                
                            }
                        }
                    }
                    

                }
                
                .onChange(of: tabSelection, { oldValue, newValue in
                    if newValue == 0{
                        Task{
                            await vm.fetchUserData()
                            vm.fetchRecentMessages()
                        }
                    }
                })
                
                .onAppear{
                    Task{
                        await vm.fetchUserData()
                        vm.fetchRecentMessages()
                    }
                }
                .onDisappear {
                    vm.cancelListeners()
                }
                .toolbar(.hidden)
                
                    
                if showButtonExplaination{
                    ZStack{
                        Color.gray.opacity(0.1).ignoresSafeArea()
                        VStack{
                            Image(.arrow)
                                .resizable()
                                .frame(width: 100,height: 100)
                                .padding(.top,50)
                                .padding(.leading,10)
                                .rotationEffect(.degrees(40))
                            
                            Text("クリックして今日の気分を更新しましょう！")
                                .font(.headline)
                                .bold()
//                                .padding(.top,50)
                            Spacer()
                        }
                            
                    }
                    .onTapGesture {
                        withAnimation {
                            showButtonExplaination = false
                            showWantToTalkMenu = true
                        }
                    }
                }
                
                
            }//End of ZStack
            .alert(vm.alertMessage, isPresented: $vm.showAlert) {
                // Custom Confirm Button
                Button(role: .destructive) {
                    Task{
                        await vm.updateUserWantToTalkStatus()
                        await vm.fetchUserData()
                        withAnimation(.bouncy) {
                            showWantToTalkMenu = false
                        }
                        
                    }
                } label: {
                    Text("確認")
                        .foregroundColor(.white)  // Customize color
                        .padding()                // Add padding if needed
                        .background(Color.red)     // Customize background color
                        .cornerRadius(8)           // Customize corner radius
                }
                
                // Cancel Button
                Button("キャンセル", role: .cancel) {
                    // Handle cancel action
                }
            } message: {
                Text("今の気分を　\(vm.wantToTalk.rawValue)　に変更しますか？。")
            }
        }
        .foregroundStyle(Color.black)

    }
}

//MARKS: View extensions

extension RecentMessagesView{
    
    
    private var customNavBar:some View{
        VStack{
            HStack{
                
                if let currentUser = vm.currentUserDB ,
                   let urlString = currentUser.photoUrl,
                   let name = currentUser.name
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
                        .onTapGesture {
                            withAnimation(.bouncy){
                                tabSelection = 2
                            }
                        }

                    Button {
                        withAnimation(.bouncy) {
                            showWantToTalkMenu.toggle()
                        }
                    } label: {
                        Text("\(name) \(currentUser.wantToTalk.rawValue)")
                            .font(.system(size: 24,weight:.bold))
                            .frame(height:55)
                        
                    }
                }
                
                
                
                Spacer()
                
            }
            .padding()
            
            if showWantToTalkMenu{
                wantToTalkSection
            }
        }
        
    }
    
    private var wantToTalkSection:some View{
        VStack(alignment: .center){
            HStack{
                Button {
                    withAnimation(.bouncy) {
                        showWantToTalkMenu = false
                    }
                } label: {
                    Image(systemName: "x.circle.fill")
                        .font(.headline)
                        .padding(.horizontal)
                }
                Spacer()

            }
            HStack{
                ForEach(WantToTalk.allCases, id: \.self) { level in
                    Button {
                        if vm.wantToTalk == level{
                            vm.showMessage(alertMessage: "確認")
                        }
                        withAnimation(.bouncy) {
                            vm.wantToTalk = level
                        }
                    } label: {
                        ZStack{
                            if vm.wantToTalk == level{
                                    RoundedRectangle(cornerRadius: 10)
                                    .fill(.customOrange)
                                        .frame(width:vm.wantToTalk == level ? 80: 50,height: 55)
                                        .cornerRadius(30)
                                        .matchedGeometryEffect(id: "backGroundRectangleId", in: nameSpace)
                            }
                            Text(level.rawValue)
                                .font(.system(size: vm.wantToTalk == level ? 50 : 30))
                                .cornerRadius(90)
                        }
                        
                    }
                    
                }
            }
            .background(.white)
            .cornerRadius(80)
        }
    }
    

   // MARKS : messagesView
    private var messagesView:some View{
        ForEach(vm.recentMessages) { recentMessage in
            
            VStack{
                
                Button {
                    self.recentMessage = recentMessage
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
            .fullScreenCover(item: $recentMessage, onDismiss: {
                Task{
                    await vm.fetchUserData()
                    vm.fetchRecentMessages()
                }
            }, content: { recentMessage in
                if let currentUser = vm.currentUserDB {
                    ChatLogView(recipient:  DBUser(recentMessage: recentMessage, currentUser: currentUser))
                }
            })
            .padding(.horizontal)
        }
}
    
}

#Preview {
    RecentMessagesView(
        showWantToTalkMenu: true,
        isUserCurrentlyLoggedOut: .constant(false),
        tabSelection: .constant(0)
    )
}

