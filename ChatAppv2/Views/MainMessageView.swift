
import SwiftUI
import Firebase
import SDWebImageSwiftUI

class MainViewMessageViewModel:ObservableObject{
    @Published var showLogOutOption : Bool = false
    @Published var chatUser : DBUser? = nil // currentUser
    @Published var isUserCurrentlyLoggedOut:Bool = true
    @Published var showNewMessageView:Bool = false
    @Published var selectedRecipient:DBUser? = nil
    @Published var recentMessages: [MessageModel] = []
    
    private var messagesListener:ListenerRegistration?
    
    
    
    init(){
        self.isUserCurrentlyLoggedOut = !AuthenticationManager.shared.checkIfUserIsAuthenticated()
        }
    
    func fetchUserData()async {
        guard let authDataResult = try? AuthenticationManager.shared.getAuthenticatedUser()else {
            print("MainViewMessageViewModel:Can't fetch user data")
            return
        }
        
            let user = try? await UserManager.shared.getUser(userId: authDataResult.uid)
            
            DispatchQueue.main.async{
                self.chatUser = user
            }
    }
    
    func logOut(){
        AuthenticationManager.shared.signOut()
        self.recentMessages = []
        self.chatUser = nil
    }
    
    
    func fetchRecentMessages() {
        guard let userId = try? AuthenticationManager.shared.getAuthenticatedUser().uid
        else {
            return
        }
        
        messagesListener = UserManager.shared.recentMessagesCollection
            .document(userId)
            .collection("messages")
            .order(by: FirebaseConstants.dateCreated, descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching recent messages: \(error.localizedDescription)")
                    return
                }
                
                guard let changes = querySnapshot?.documentChanges else { return }
                
                changes.forEach { change in
                    let docId = change.document.documentID
                    
                    if change.type == .added || change.type == .modified {
                        if let index = self.recentMessages.firstIndex(where: { $0.documentId == docId }) {
                            self.recentMessages.remove(at: index)
                        }
                        let messageData = change.document.data()
                        let recentMessage = MessageModel(documentId: docId, data: messageData)
                        self.recentMessages.insert(recentMessage, at: 0)
                    }
                    
                    if change.type == .removed {
                        self.recentMessages.removeAll { $0.documentId == docId }
                    }
                }
            }
    }
    
    
    @MainActor
    func refreshData() async {
        // Cancel existing listener
        messagesListener?.remove()

        // Fetch user data
        await fetchUserData()

        // Fetch recent messages
        fetchRecentMessages()
    }
    
    func cancelListeners() {
        messagesListener?.remove()
    }
    
    deinit {
        cancelListeners()
    }
}


struct MainMessageView: View {
    @StateObject var vm = MainViewMessageViewModel()
    var body: some View {
        NavigationStack{
            
            VStack{
                NavigationLink {
                    ProfileView(isUser: true)
                } label: {
                    customNavBar
                        .foregroundStyle(Color(.black))
                }

                ScrollView{
                    messagesView
                }
                .refreshable {
                    await vm.refreshData()
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
            .navigationDestination(for: DBUser.self, destination: { user in
                ChatLogView(recipient: user)
            })
            .navigationDestination(item: $vm.selectedRecipient, destination: { user in
                ChatLogView(recipient: user)
            })
            
            .overlay(newMessageButton,alignment: .bottom)
            .toolbar(.hidden)
        }
    }
}

//MARKS: View extensions

extension MainMessageView{
    
    
    private var customNavBar:some View{
        HStack{
            WebImage(url: URL(string: vm.chatUser?.photoUrl ?? "NO Image url found")) { image in
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
                ProgressView(value: 0.8)
                    .frame(width: 50,height: 50)
                    .padding()
            }

            VStack(alignment:.leading,spacing: 4){
                let name = vm.chatUser?.name ?? "Can't get name"
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

                NavigationLink(value: DBUser(recentMessage: recentMessage, currentUser: vm.chatUser ?? DBUser(userId:""))) {
                    
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
                            ProgressView(value: 0.8)
                                .frame(width: 65,height: 65)
                                .padding()
                            
                        }
                        
                        VStack(alignment:.leading){
                            if recentMessage.senderName == vm.chatUser?.name ?? "No email"{
                                Text(recentMessage.recieverName)
                                    .font(.system(size: 16,weight: .bold))
                            }else{
                                Text(recentMessage.recieverName)
                                    .font(.system(size: 16,weight: .bold))
                            }
                            
                            Text(recentMessage.text)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(.lightGray))
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
                                 .opacity(recentMessage.isUnread ? 1 : 0)
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
            vm.showNewMessageView = true
        } label: {
            HStack{
                Spacer()
                Text("+ New Message")
                    .font(.system(size: 16,weight: .bold))
                Spacer()
            }
            .foregroundStyle(Color(.white))
            .padding(.vertical)
            .background(.blue)
            .cornerRadius(32)
            .padding(.horizontal)
            .shadow(radius: 15)
        }
        .fullScreenCover(isPresented: $vm.showNewMessageView) {
            CreateNewMessageView { user in
                print(user.email ?? "")
                vm.selectedRecipient = user
            }
        }
    }
}

