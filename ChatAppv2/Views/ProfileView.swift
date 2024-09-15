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
    @Published var newName:String = ""
    
    @Published var imageSelection:PhotosPickerItem? = nil
    
    @Published var showAlert:Bool = false
    @Published var alertTitle:String = ""
    
    
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
        user?.preferences?.contains(text) == true
    }
    
    func loadCurrentUser()throws {
        let authDataResult = try  AuthenticationManager.shared.getAuthenticatedUser()
        Task{
            if let fetchedUser = try? await UserManager.shared.getUser(userId: authDataResult.uid){
                await MainActor.run {
                    self.user = fetchedUser
                }
            }
        }
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
    }


}
enum EditingOprions{
    case EditingName
    case EditiingPreferences
}
struct ProfileView: View {
    @Binding var isUserCurrentlyLogOut:Bool
    @StateObject var vm = ProfileViewModel()
    @State private var isEditing = false
    @State private var editingOption:EditingOprions? = nil
    var isUser: Bool

    // Custom colors
    private let accentColor = Color.customOrange
    private let textColor = Color.primary
    private let subtitleColor = Color.gray

    var body: some View {
        ZStack{
            ScrollView(showsIndicators:false){
                VStack(spacing: 10) {
                    ImagePickerView
                        .onAppear{
                            checkThePermission()
                        }
                        .overlay(alignment:.bottomTrailing) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color(.blue))
                        }
                        .onChange(of: vm.imageSelection) {
                            Task{
                                await vm.loadTransferableImage()
                            }

                        }
                    
                    Text(vm.user?.name ?? "Error" )
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .onTapGesture {
                            withAnimation {
                                editingOption = .EditingName
                            }
                        }
                    
                    // User Email
                        if let email = vm.user?.email {
                            Text(email)
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
                    
                    
                }
                .padding()
                .background(Color.customBlack)
                .cornerRadius(15)
                .shadow(color: .gray.opacity(0.2), radius: 10, x: 0, y: 5)
                .padding()
                .navigationTitle(isUser ? "Your Profile" : "\(vm.user?.name ?? "User")'s Profile")
                .navigationBarTitleDisplayMode(.inline)
                .alert(isPresented: $vm.showAlert) {
                    Alert(title: Text(vm.alertTitle))
                }
                .onAppear{
                    try? vm.loadCurrentUser()
                }
                
            }
            
            //Editing Views
            switch editingOption {
            case .EditingName:
                changeNameView
            case .EditiingPreferences:
                userInterestsSection
            case nil:
                Text("")
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
        .overlay(alignment: .bottom, content: {
            if editingOption == nil && !vm.isLoading {
                Button {
                    vm.logOut()
                    isUserCurrentlyLogOut = !AuthenticationManager.shared.checkIfUserIsAuthenticated()
                } label: {
                    Text("サインアウトする")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                        .shadow(radius: 20)
                }
            }
        })
        .navigationBarBackButtonHidden(editingOption != nil || vm.isLoading ? true : false)    }
    
    // Displaying selected preferences when not editing
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack{
                Text("Preferences")
                    .font(.headline)
                    .foregroundColor(accentColor)
                    .padding(.bottom, 4)
                Spacer()
                Button {
                    editingOption = .EditiingPreferences
                } label: {
                    Image(systemName: "pencil")
                        .font(.title2)
                        .foregroundStyle(Color(.blue))
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
                        editingOption = nil
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

    // Function to save changes
    private func saveChanges() {
        if vm.newName.isEmpty{
            vm.showAlert(title: "新しい名前を入力してください！！")
        }else{
            Task{
                await vm.updateName()
            }
        }
    }
    
    private func saveNewName(){
        if vm.newName.isEmpty{
            vm.showAlert(title: "新しい名前を入力してください！！")
        }else{
            Task{
                await vm.updateName()
                DispatchQueue.main.async {
                    editingOption = nil
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
            PhotosPicker(selection: $vm.imageSelection,matching: .images) {
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
                        editingOption = nil
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
                            .background(.blue.gradient)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    Button {
                        editingOption = nil
                    } label: {
                        Text("キャンセル")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.red.gradient)
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
    "スポーツ", "音楽", "映画", "読書", "料理", "旅行", "ゲーム", "アート",
    "写真撮影", "フィットネス", "ヨガ", "ダンス", "ハイキング", "キャンプ", "ガーデニング",
    "釣り", "ボランティア活動", "登山", "自転車", "ボードゲーム", "アニメ", "マンガ",
    "瞑想", "書道", "手芸", "ドローン", "カフェ巡り", "DIY", "サイクリング", "プログラミング",
    "言語学習", "ペットの世話"
]

#Preview {
    NavigationStack{
        ProfileView(isUserCurrentlyLogOut: .constant(false), isUser: true)
    }
}
