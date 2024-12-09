//
//  ProfileView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 9/13/24.
//
import SwiftUI
import Firebase
import SDWebImageSwiftUI
import _PhotosUI_SwiftUI

@MainActor
final class ProfileViewModel:ObservableObject{
    @Published var isLoading:Bool = false
    @Published var progress:Double = 0.0
    @Published var user :DBUser? = nil
    @Published var passedUserId:String? = nil
    @Published var newName:String = ""
    @Published var newBio:String = ""
    
    @Published var imageSelection:PhotosPickerItem? = nil
    
    @Published var showAlert:Bool = false
    @Published var alertTitle:String = ""
    
    @Published var editingOption:EditingOprions? = nil


    init(passedUserId:String){
        self.passedUserId = passedUserId
    }
    
    func loadTransferableImage()async{
        isLoading = true
        progress = 0
    
        guard let imageSelection else {
            print("No imageSelection")
            return
        }
        updateProgress(0.2)
        Task {
            do {
                let transferableImage = try await imageSelection.loadTransferable(type: TransferableImage.self)
                updateProgress(0.3)
                let newImage = transferableImage?.image
                updateProgress(0.4)
                await saveNewImage(newImage: newImage)
                try await reloadUser()
                updateProgress(1)
                isLoading = false
            } catch {
                print("Failed to load transferable image: \(error)")
                isLoading = false
            }
        }
    }
    
    func saveNewImage(newImage:UIImage?) async{
        guard let user = self.user,
              let newImage = newImage
        else{return}
        
        guard let downLoadUrl = try? await UserManager.shared.saveImageInStorage(image: newImage, userId: user.userId)else {return}
        updateProgress(0.5)
        UserManager.shared.changeNewProfileImageUrl(downloadUrl: downLoadUrl, userId: user.userId)
        updateProgress(0.8)
    }
    
    func showAlert(title:String){
        self.showAlert = true
        self.alertTitle = title
    }
    
    func preferenceIsSelected(_ text:String) -> Bool{
        user?.preferences.contains(text) == true
    }
    
    func loadAuthenticatedUser() async{
        guard let authDataResult = try? AuthenticationManager.shared.getAuthenticatedUser() else{return}
        
        if let fetchedUser = try? await UserManager.shared.getUser(userId: authDataResult.uid) {
            DispatchQueue.main.async {
                self.user = fetchedUser
            }
        }
    }
    
    func loadCurrentUser()async throws {
        guard let passedUserId = self.passedUserId else{
            print("ProfileViewModel/loadCurrentUser : Can't get the passedUserId")
            await loadAuthenticatedUser()
            return
        }
        Task{
            if let fetchedUser = try? await UserManager.shared.getUser(userId: passedUserId){
                await MainActor.run {
                    self.user = fetchedUser
                }
            }
        }
    }
    
    func updateBio()async{
        guard let user = self.user else{return}
        try? await UserManager.shared.updateUserBio(userId: user.userId, newBio: newBio)
        try? await reloadUser()
    }
    
    func updateName() async{
        guard let user = self.user else{return}
        try? await UserManager.shared.updateUserName(userId:user.userId , name: newName)
        try? await reloadUser()
    }
    func removePreference(interest:String) async {
        guard let user = self.user else{
            print("ProfileViewModel/removePreference : can't get the user")
            return
        }
        do {
            try await UserManager.shared.removeUserPreference(userId: user.userId, preference: interest)
            try await reloadUser()
        } catch {
            print("Error removing interest: \(error.localizedDescription)")
        }
        
    }
    
    func addPreference(interest:String)async{
        guard let user = self.user else{
            print("ProfileViewModel/addPreference:Can't get user")
            return
        }
        do {
            try await UserManager.shared.addUserPreference(userId: user.userId, preference: interest)
            try await reloadUser()

        } catch {
            print("Error adding interest:\(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func reloadUser() async throws{
        guard let user = self.user else{
            return
        }
        if let updatedUser = try? await UserManager.shared.getUser(userId: user.userId){
            self.user = updatedUser
        }
        
    }
    
    @MainActor
    private func updateProgress(_ newProgress: Double) {
        progress = newProgress
    }
    
    func logOut(){
        AuthenticationManager.shared.signOut()
        self.user = nil
        self.passedUserId = nil
    }


}
enum EditingOprions{
    case EditingName
    case EditiingPreferences
    case EditingBio
}
struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isUserCurrentlyLogOut:Bool
    @StateObject var vm : ProfileViewModel
    var isUser:Bool
    var isFromChatView:Bool
    @State var user : DBUser? = nil
    @Binding var showTabBar:Bool
    @Binding var tabSelection:Int
    
    init(passedUserId:String,isUserCurrentlyLogOut:Binding<Bool>,isFromChatView:Bool,isUser:Bool,showTabBar:Binding<Bool>,tabSelection:Binding<Int>){
        _vm = StateObject(wrappedValue: ProfileViewModel(passedUserId: passedUserId))
        self.isUser = isUser
        _isUserCurrentlyLogOut = isUserCurrentlyLogOut
        self.isFromChatView = isFromChatView
        _showTabBar = showTabBar
        _tabSelection = tabSelection
    }

    // Custom colors
    private let accentColor = Color.customOrange
    private let textColor = Color.primary
    private let subtitleColor = Color.gray

    var body: some View {
        ZStack{
            ScrollView(showsIndicators:false){
                VStack(spacing: 10) {
                    ImagePickerView
                        .overlay(alignment: .topLeading, content: {
                            if !isUser{
                                if let wantToTalk = vm.user?.wantToTalk.rawValue{
                                    Text(wantToTalk)
                                        .font(.title)
                                }
                            }
                        })
                        .onAppear{
                            checkThePermission()
                        }
                    
                        .overlay(alignment:.bottomTrailing) {
                            if isUser{
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color(.customOrange))
                            }
                        }
                        .onChange(of: vm.imageSelection) {
                            Task{
                                await vm.loadTransferableImage()
                            }

                        }
                        .onChange(of: vm.editingOption) { _, _ in
                            if vm.editingOption == nil{
                                showTabBar = true
                            }else{
                                showTabBar = false
                            }
                        }
                    
                    Text(vm.user?.name ?? "Error" )
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .onTapGesture {
                            if isUser{
                                withAnimation(.easeIn) {
                                    vm.editingOption = .EditingName
                                }
                            }
                        }
                    
                        userBioSection
                    // User Email
                        if let email = vm.user?.email{
                            Text(email.replacingOccurrences(of: "@jec.ac.jp", with: ""))
                                .font(.subheadline)
                                .foregroundColor(subtitleColor)
                        }
                    
                    
                    // User Age
                        if let age = vm.user?.age {
                            Text("Age: \(Int(age))")
                                .font(.subheadline)
                                .foregroundColor(subtitleColor)
                        }
                    
                   
                    preferencesSection
                    
                    Spacer()
                    
                    if vm.editingOption == nil && !vm.isLoading && isUser {
                        signOutButton
                    }
                    if !isUser{
                        if let user = vm.user{
                            if isFromChatView{
                                Button {
                                    presentationMode.wrappedValue.dismiss()
                                } label: {
                                    Text("メッセージを送る")
                                        .font(.headline)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                        .shadow(radius: 20)

                                }
                            }
                            else{
                                Button {
                                    self.user = user
                                } label: {
                                    Text("メッセージを送る")
                                        .font(.headline)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                        .shadow(radius: 20)
                                }

                            }
                            
                            Spacer()
                        }

                    }

                }
                .padding()
                .background(Color.customBlack)
                .cornerRadius(15)
                .shadow(color: .gray.opacity(0.2), radius: 10, x: 0, y: 5)
                .padding()
                .navigationTitle(isUser ? "Your Profile" : "\(vm.user?.name ?? "User")'s Profile")
                .navigationBarTitleDisplayMode(.inline)
                .padding(.bottom,50) //for the tab bar
                .alert(isPresented: $vm.showAlert) {
                    Alert(title: Text(vm.alertTitle))
                }
                .task{
                    try? await vm.loadCurrentUser()
                }
                .fullScreenCover(item: $user) { user in
                    ChatLogView(recipient:user)
                }

                
            }
            .safeAreaInset(edge: .top, content: {
                customNavBar
            })

            
            //Editing Views
            switch vm.editingOption {
            case .EditingName:
                changeNameView
            case .EditiingPreferences:
                userInterestsSection
            case nil:
                Text("")
            case .EditingBio:
                changeBioView
            }
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
        }
        .toolbar(.hidden)
    }
    private var userBioSection:some View{
        HStack{
            Text(vm.user?.bio ?? "こんにちは..")
                .font(.subheadline)
                .foregroundColor(subtitleColor)
                .multilineTextAlignment(.center)
            if isUser{
                Button {
                    withAnimation(.easeIn){
                        vm.editingOption = .EditingBio
                    }
                } label: {
                    Image(systemName: "pencil")
                        .font(.title2)
                        .foregroundStyle(Color(.blue))
                }
            }

        }
    }
    private var customNavBar:some View{
        HStack{
            if !isUser{
                Button{
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }

            Spacer()
            if let user = vm.user,
               let name = user.name
            {
                Text(isUser ? "Your Profile" : "\(name)'s Profile")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .background(.white)
    }
    
    // Displaying selected preferences when not editing
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack{
                Text("Preferences")
                    .font(.headline)
                    .foregroundColor(accentColor)
                    .padding(.bottom, 4)
                Spacer()
                if isUser{
                    Button {
                        withAnimation(.easeIn){
                            vm.editingOption = .EditiingPreferences
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .font(.title2)
                            .foregroundStyle(Color(.blue))
                    }
                }

            }
            
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.user?.preferences ?? [], id: \.self) { preference in
                        HStack {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 8, height: 8)
                            Text(preference)
                                .font(.body)
                                .foregroundColor(textColor)
                        }
                        .padding(.vertical, 4) // Add vertical padding to each item
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 5)
    }
    
    // Editable interests section using the existing userInterestsSection
    private var userInterestsSection: some View {
        ZStack{
            Color.customBlack.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack{
                    Text("興味のある分野を選択してください")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(.customBlack)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(interests, id: \.self) { interest in
                            Button {
                                if vm.preferenceIsSelected(interest) {
                                    Task{
                                        await vm.removePreference(interest: interest)
                                    }
                                } else {
                                    Task{
                                        await vm.addPreference(interest: interest)
                                    }
                                }
                            } label: {
                                Text(interest)
                                    .font(.headline)
                                    .foregroundColor(vm.preferenceIsSelected(interest) ? .white : .customOrange)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(vm.preferenceIsSelected(interest) ? Color.customOrange : Color.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.bottom,100)
            }
            VStack{
                Spacer()
                ZStack{
                    Color.customBlack.ignoresSafeArea()
                    Button {
                        withAnimation(.easeIn){
                            vm.editingOption = nil
                        }
                    } label: {
                        Text("戻る")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding()
                            .shadow(radius: 20)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                
            }

        }
    }
    
    private var signOutButton:some View{
        Button {
            vm.logOut()
            isUserCurrentlyLogOut = !AuthenticationManager.shared.checkIfUserIsAuthenticated()
            tabSelection = 0
        } label: {
            Text("サインアウトする")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.red)
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 20)
        }
    }

    
    private func saveNewName(){
        if vm.newName.isEmpty{
            vm.showAlert(title: "新しい名前を入力してください！！")
        }else{
            Task{
                await vm.updateName()
                DispatchQueue.main.async {
                    withAnimation(.default){
                        vm.editingOption = nil
                    }
                }
            }
            
        }
    }
    
    private func saveNewBio(){
        if vm.newBio.isEmpty{
            vm.showAlert(title: "新しい自己紹介を入力してください！！")
        }else{
            Task{
                await vm.updateBio()
                DispatchQueue.main.async {
                    withAnimation(.easeIn){
                        vm.editingOption = nil
                    }
                }
            }
        }
    }
    
    private func checkThePermission(){
        let accessType = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if accessType != .authorized{
            Task{
                await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            }
        }
    }
}


extension ProfileView{
    private var ImagePickerView : some View{
        VStack{
            if isUser{
                PhotosPicker(selection: $vm.imageSelection,matching: .images) {
                    profileImage
                }
            }else{
                profileImage
            }
        }
    }
    
    private var profileImage:some View{
        VStack{
            WebImage(url: URL(string: vm.user?.photoUrl ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.white), lineWidth: 4)
                    )
                    .shadow(color: .gray.opacity(0.4), radius: 10, x: 0, y: 5)
            } placeholder: {
                Image(.profilePic)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
            }
            
        }
    }
}

// MARK:- editor Views
extension ProfileView{
    private var changeNameView:some View{
        ZStack{
            Color.black.opacity(0.9).ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        vm.editingOption = nil
                    }
                }
            VStack{
                Spacer()
                Text("新しい名前を入力してください")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.customWhite)
                
                TextField("ここに名前を入力...", text: $vm.newName)
                    .font(.headline)
                    .frame(height: 55)
                    .padding(.horizontal)
                    .background(.white)
                    .cornerRadius(10)
                
                Spacer()
                VStack{
                    Button {
                        saveNewName()
                    } label: {
                        Text("保存")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    Button {
                        vm.editingOption = nil
                    } label: {
                        Text("キャンセル")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom)

            }
            .padding()
        }
    }
    
    private var changeBioView:some View{
        ZStack{
            Color.black.opacity(0.9).ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        vm.editingOption = nil
                    }
                }
            VStack{
                Spacer()
                Text("自己紹介を入力してください")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.customWhite)
                
                TextField("ここに自己紹介を入力...", text: $vm.newBio)
                    .font(.headline)
                    .frame(height: 55)
                    .padding(.horizontal)
                    .background(.white)
                    .cornerRadius(10)
                
                Spacer()
                VStack{
                    Button {
                        saveNewBio()
                    } label: {
                        Text("保存")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    Button {
                        vm.editingOption = nil
                    } label: {
                        Text("キャンセル")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom)

            }
            .padding()
        }
    }
}


let interests = [
    // 元のリスト
    "スポーツ", "音楽", "映画", "読書", "料理", "旅行", "ゲーム", "アート",
    "写真撮影", "フィットネス", "ヨガ", "ダンス", "ハイキング", "キャンプ", "ガーデニング",
    "釣り", "ボランティア活動", "登山", "自転車", "ボードゲーム", "アニメ", "マンガ",
    "瞑想", "書道", "手芸", "ドローン", "カフェ巡り", "DIY", "サイクリング", "プログラミング",
    "言語学習", "ペットの世話", "謎解き",
    // 前回追加したもの
    "バードウォッチング", "ワイン試飲", "陶芸", "スキューバダイビング", "天体観測",
    "ジグソーパズル", "コスプレ", "ビデオ編集", "盆栽", "クラシック音楽鑑賞",
    // 新しく追加する趣味
    "茶道", "華道", "囲碁", "将棋", "カリグラフィー", "折り紙", "切り絵", "漫才", "落語",
    "篆刻", "剣道", "弓道", "相撲観戦", "歌舞伎鑑賞", "能・狂言鑑賞", "和太鼓",
    "三味線", "琴", "尺八", "日本舞踊", "着物の着付け", "香道", "パン作り", "そば打ち",
    "フラワーアレンジメント", "ミニチュア製作", "ドールハウス作り", "鉄道模型",
    "切手収集", "コイン収集", "アンティーク収集", "ワインセラー管理", "ウイスキー蒐集",
    "ハーブ栽培", "盆景", "苔玉作り", "テラリウム作り", "昆虫採集", "化石発掘",
    "星座観察", "気象観測", "グランピング", "サバイバルキャンプ", "ロッククライミング",
    "パラグライダー", "スカイダイビング", "バンジージャンプ", "カヌー", "ラフティング"
]
