//
//  ProfileView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 9/13/24.
//
import SwiftUI
import Firebase
import SDWebImageSwiftUI

@MainActor
final class ProfileViewModel:ObservableObject{
    @Published var user :DBUser? = nil
    @Published var newName:String = ""
    
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
}

struct ProfileView: View {
    @StateObject var vm = ProfileViewModel()
    @State private var isEditing = false
    var isUser: Bool

    // Custom colors
    private let accentColor = Color.blue
    private let backgroundColor = Color(.systemGray6)
    private let textColor = Color.primary
    private let subtitleColor = Color.gray

    var body: some View {
        VStack(spacing: 20) {
            WebImage(url: URL(string: vm.user?.photoUrl ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.customBlack), lineWidth: 4)
                    )
                    .shadow(color: .gray.opacity(0.4), radius: 10, x: 0, y: 5)
            } placeholder: {
                ProgressView()
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
            }
            .padding(.top, 16)
            
            // Editable Name
            if isEditing {
                TextField(vm.user?.name ?? "", text: $vm.newName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textColor)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
            } else {
                Text(vm.user?.name ?? "Error" )
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textColor)
            }
            
            // User Email
            if !isEditing{
                if let email = vm.user?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(subtitleColor)
                }
            }
            
            // User Age
            if !isEditing{
                if let age = vm.user?.age {
                    Text("Age: \(Int(age))")
                        .font(.subheadline)
                        .foregroundColor(subtitleColor)
                }
            }
            
            // Editable Preferences Section
            if isEditing {
                userInterestsSection
            } else {
                preferencesSection
            }
            
            Spacer()
            
            // Edit Button
            Button(action: {
                isEditing.toggle()
                if !isEditing {
                    // Save the changes when finished editing
                    saveChanges()
                }
            }) {
                Text(isEditing ? "Save" : "Edit Profile")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
        }
        .onAppear{
            try? vm.loadCurrentUser()
        }

        .padding()
        .background(backgroundColor)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding()
        .navigationTitle(isUser ? "Your Profile" : "\(vm.user?.name ?? "User")'s Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Displaying selected preferences when not editing
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preferences")
                .font(.headline)
                .foregroundColor(accentColor)
                .padding(.bottom, 4)
            
            ForEach(vm.user?.preferences ?? [], id: \.self) { preference in
                HStack {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 8, height: 8)
                    Text(preference)
                        .font(.body)
                        .foregroundColor(textColor)
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
        }
    }

    // Function to save changes
    private func saveChanges() {
        Task{
            await vm.updateName()
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
        ProfileView(isUser: true)
    }
}
