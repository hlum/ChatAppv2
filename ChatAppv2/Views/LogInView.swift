//
//  ContentView.swift
//  MessageApp
//
//  Created by Hlwan Aung Phyo on 8/28/24.
//

import SwiftUI
import PhotosUI
import GoogleSignInSwift


//import Firebase
//import FirebaseAuth
//import FirebaseStorage


final class LogInViewModel: ObservableObject {
    @Published var loginStatusMessage: String = ""
    @Published var isLoginMode = false
    @Published var email = ""
    @Published var password = ""
    @Published var imageSelection: PhotosPickerItem? = nil
    @Published var profileImage: UIImage?
    @Published var logineduser:AuthDataResultModel? = nil
    
    
    func loadTransferableImage() {
        guard let imageSelection else { return }
        
        Task {
            do {
                let transferableImage = try await imageSelection.loadTransferable(type: TransferableImage.self)
                await MainActor.run {
                    self.profileImage = transferableImage?.image
                    self.loginStatusMessage = "profile image loaded"
                }
            } catch {
                print("Failed to load transferable image: \(error)")
                await MainActor.run {
                    self.loginStatusMessage = "Failed to load image: \(error.localizedDescription)"
                }
            }
        }
    }
}

//SignIn with email
extension LogInViewModel{
    func handleAction()async{
        if self.isLoginMode {
            await self.signInUser()
        }else{
            await self.createNewUser()
        }
    }
    
    func createNewUser()async{
        guard let _ = self.imageSelection else {
            DispatchQueue.main.async {
                self.loginStatusMessage = "Please select an image"
            }
            return
        }
                
                
        do {
            let authDataResult = try await AuthenticationManager.shared.createNewUser(email: self.email, password: self.password)
            
            DispatchQueue.main.async {
                self.loginStatusMessage = "Account Created Successfully"
            }
            
            //Save the new user in the data base
            guard let profileImage = self.profileImage else {
                return
            }
            let photoUrl = try? await UserManager.shared.saveImageInStorage(image: profileImage, userId: authDataResult.uid)
            let user = DBUser(authDataResult: authDataResult,photoUrl: photoUrl,preferences: [],name:"",age: 1)
            await UserManager.shared.storeNewUser(user: user)
            
            DispatchQueue.main.async {
                self.loginStatusMessage = "Account Created Successfully"
            }
            
        } catch {
            await MainActor.run {
                self.loginStatusMessage = "Failed to create account\(error.localizedDescription)"
            }
            print("Error: \(error.localizedDescription)")
        }
        
        

    }
    
    func signInUser() async {
        do{
            try await AuthenticationManager.shared.signIn(email: self.email, password: self.password)
            print("Sign In")
        }catch{
            DispatchQueue.main.async {
                self.loginStatusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}


//SignIn with Google
extension LogInViewModel {
    func signInWithGoogle() async throws {
        let helper = SignInGoogleHelper()
        let tokens = try await helper.signIn()
        let authDataResult = try await AuthenticationManager.shared.signInWithGoogle(tokens: tokens)
        
        // Check if the user is new
        let isNewUser = !(try await UserManager.shared.checkIfUserExistInDatabase(userId: authDataResult.uid))
        
        if isNewUser {
            DispatchQueue.main.async {
                self.logineduser = authDataResult
            }
            
        }
    }
}

struct LogInView: View {
    @StateObject var vm = LogInViewModel()
    @Binding var isUserCurrentlyLoggedOut : Bool
    var body: some View {
        
        VStack {
            NavigationStack{
                
                ScrollView{
                    VStack(spacing: 16){
                        TabBarView
                        
                        if !vm.isLoginMode{
                            ImagePickerView
                                .onAppear{
                                    Task{
                                        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                                    }
                                }
                        }
                        
                        LoginFieldView
                        Text(vm.loginStatusMessage)
                            .foregroundColor(.red)
                        
                    }
                    .padding()
                }
                .navigationDestination(item: $vm.logineduser, destination: { user in
                    NewUserFormView(isUserCurrentlyLoggedOut: $isUserCurrentlyLoggedOut, user: user)
                })
                .navigationTitle(vm.isLoginMode ? "Login" : "Create Account")
                .background(Color(.init(white:0,alpha:0.05))
                    .ignoresSafeArea())
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
       
        .onChange(of: vm.imageSelection) {
            vm.loadTransferableImage()
        }
        
    }
}


extension LogInView{
    private var ImagePickerView : some View{
        VStack{
            PhotosPicker(selection: $vm.imageSelection,matching: .images) {
                VStack{
                    if let image = vm.profileImage{
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(Circle())
                            .frame(width: 128, height: 128)
                        
                    }else{
                        Image(systemName:"person.fill")
                            .font(.system(size: 128))
                            .overlay(
                                Circle()
                                    .stroke(lineWidth: 3)
                                    .frame(width:150,height: 150)
                                
                            )
                            .foregroundColor(.gray)
                    }
                    
                }
                .padding(.vertical)
            }
            if vm.imageSelection != nil{
                Button("Remove Image"){
                    vm.imageSelection = nil
                    vm.profileImage = nil
                }
            }
        }
    }
    
    private var LoginFieldView:some View{
        VStack{
            Group{
                TextField("Email...", text: $vm.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password...", text: $vm.password)
                
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .padding(12)
            .background(.white)
            .cornerRadius(8)
            
            Button {
                Task{
                    await vm.handleAction()
                    self.isUserCurrentlyLoggedOut = false
                }
                
            } label: {
                Text(vm.isLoginMode ? "Login" : "Create Account")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(.blue)
                    .cornerRadius(10)
            }
            Button {
                Task{
                    try await vm.signInWithGoogle()
                }
            } label: {
                Text("Sign In with Google")
                    .font(.headline)
                    .foregroundStyle(Color(.white))
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color(.blue))
                    .cornerRadius(10)
            }
        }
    }
    
    private func toggleIsUserCurrentlyLoggedOut(){
        self.isUserCurrentlyLoggedOut = !AuthenticationManager.shared.checkIfUserIsAuthenticated()
    }
    
    private var TabBarView:some View{
        Picker(selection: $vm.isLoginMode) {
            Text("Login")
                .tag(true)
            Text("Create Account")
                .tag(false)
        } label: {
            Text("Picker Here")
        }
        .pickerStyle(SegmentedPickerStyle())
    }
}

//#Preview {
//    LogInView(isUserCurrentlyLoggedOut: .constant(true))
//}




struct NewUserFormView:View {
    @Binding var isUserCurrentlyLoggedOut: Bool
    let user: AuthDataResultModel
    var body: some View {
        Text(user.email ?? "No email")
        Button("Close the form view"){
            isUserCurrentlyLoggedOut = false
        }
    }
}

#Preview{
    NewUserFormView(
        isUserCurrentlyLoggedOut: .constant(true),
        user:AuthDataResultModel(
            uid: "UIddsafdsfsd",
            email: "hlumaungphyo@gmail.com",
            photoUrl: "httpasfasf"
        )
    )
}
