
import SwiftUI
import SDWebImageSwiftUI

class MainViewMessageViewModel:ObservableObject{
    @Published var showLogOutOption : Bool = false
    @Published var chatUser : DBUser? = nil //currentUser
    @Published var isUserCurrentlyLoggedOut:Bool = true
    @Published var showNewMessageView:Bool = false
    @Published var selectedRecipient:DBUser? = nil
    @Published var recentMessages: [MessageModel] = []
    
    
    init(){
        fetchUserData()
        self.isUserCurrentlyLoggedOut = !AuthenticationManager.shared.checkIfUserIsAuthenticated()
        fetchRecentMessages()
        print(recentMessages.count)
    }
    
    
    
    private func fetchUserData() {
        guard let authDataResult = try? AuthenticationManager.shared.getAuthenticatedUser()else {
            print("MainViewMessageViewModel:Can't fetch user data")
            return
        }
        Task{
            let user = try? await UserManager.shared.getUser(userId: authDataResult.uid)
            
            DispatchQueue.main.async{
                self.chatUser = user
            }
            print("MainViewMessageViewModel:Successfully fetched user data")
        }
    }
    
    func logOut(){
        AuthenticationManager.shared.signOut()
        self.chatUser = nil
    }
    
    
    func fetchRecentMessages() {
        guard let userId = try? AuthenticationManager.shared.getAuthenticatedUser().uid
        else {
            print("")
            return
        }
        
        UserManager.shared.recentMessagesCollection
            .document(userId)
            .collection("messages")
            .order(by: FirebaseConstants.dateCreated, descending: true)
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
                        dump(recentMessage)
                        self.recentMessages.insert(recentMessage, at: 0)
                    }
                    
                    if change.type == .removed {
                        self.recentMessages.removeAll { $0.documentId == docId }
                    }
                }
            }
    }
}


struct MainMessageView: View {
    @StateObject var vm = MainViewMessageViewModel()
    
    var body: some View {
        NavigationStack{
            
            VStack{
                customNavBar
                ScrollView{
                    messagesView
                }
                
                
            }
            .navigationDestination(item: $vm.selectedRecipient, destination: { user in
                Text(user.email ?? "")
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
            AsyncImage(url: URL(string: vm.chatUser?.photoUrl ?? "")) { image in
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
            }
            
            
            //            Image(systemName: "person.fill")
            //                .font(.system(size:34,weight: .heavy))
            VStack(alignment:.leading,spacing: 4){
                let email = vm.chatUser?.email ?? "can't find userEmail"
                Text(email.replacingOccurrences(of: "@gmail.com", with: "さん"))
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
        .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut, onDismiss: nil) {
            LogInView(isUserCurrentlyLoggedOut: $vm.isUserCurrentlyLoggedOut)
        }
        
    }
    
    
    
    private var messagesView:some View{
        ForEach(vm.recentMessages) { recentMessage in
            
            VStack{
                
                NavigationLink {
                    Text("d")
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
                            ProgressView(value: 0.8)
                                .frame(width: 65,height: 65)
                                .padding()
                            
                        }
                        
                        
                        //                        AsyncImage(url: URL(string: recentMessage.recipientProfileUrl)) { phase in
                        //                            if let error = phase.error {
                        //                                Text("Error loading image: \(error.localizedDescription)")
                        //                            }
                        //                            if let image = phase.image{
                        //                                image.resizable()
                        //                            }
                        //
                        //                        }
                        //                        AsyncImage(url: URL(string: recentMessage.recipientProfileUrl)) { image in
                        //                            image
                        //                                .resizable()
                        //                                .aspectRatio(contentMode: .fill)
                        //                                .frame(width:65,height: 65)
                        //                                .cornerRadius(65)
                        //                                .overlay(RoundedRectangle(cornerRadius: 44)
                        //                                    .stroke(Color(.label),lineWidth: 1)
                        //                                )
                        //                                .padding()
                        
                        //                        } placeholder: {
                        //                            ProgressView()
                        //                                .frame(width: 65,height: 65)
                        //                                .padding()
                        //                        }
                        
                        
                        VStack(alignment:.leading){
                            if recentMessage.senderEmail == vm.chatUser?.email ?? ""{
                                Text(recentMessage.senderEmail)
                                    .font(.system(size: 16,weight: .bold))
                            }else{
                                Text(recentMessage.recipientEmail)
                                    .font(.system(size: 16,weight: .bold))
                            }
                            
                            Text(recentMessage.text)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(.lightGray))
                        }
                        Spacer()
                        Text("2 min")
                            .font(.system(size: 14,weight: .semibold))
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

