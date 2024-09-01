//
//  ContentView.swift
//  MessageApp
//
//  Created by Hlwan Aung Phyo on 8/28/24.
//

import SwiftUI
import PhotosUI


//import Firebase
//import FirebaseAuth
//import FirebaseStorage

final class LogInViewModel:ObservableObject {
    @Published var loginStatusMessage :String = ""
    @Published var showImagePicker = false
    @Published var isLoginMode = false
    @Published var email = ""
    @Published var password = ""
    @Published var imageItem : PhotosPickerItem? = nil
    @Published var imageData: UIImage? = nil
    //    @Published var isUserCurrentlyLoggedOut:Bool = true
    
    func handleAction()async{
        if self.isLoginMode {
            await self.signInUser()
        }else{
            await self.createNewUser()
        }
    }
    func createNewUser()async{
        guard let imageData = self.imageData else {
            self.loginStatusMessage = "Please select an image"
            return
        }
        guard let authDataResult = try? await AuthenticationManager.shared.createNewUser(email: self.email, password: self.password) else{
            return
        }
        DispatchQueue.main.async {
            self.loginStatusMessage = "Account Created Successfully"
        }
        
        //Save the new user in the data base
        let photoUrl = try? await UserManager.shared.saveImageInStorage(image: imageData, userId: authDataResult.uid)
        let user = DBUser(authDataResult: authDataResult,photoUrl: photoUrl)
        await UserManager.shared.storeNewUser(user: user)
        DispatchQueue.main.async {
            self.loginStatusMessage = "Account Created Successfully"
        }

    }
    
    func signInUser() async {
        do{
            try await AuthenticationManager.shared.signIn(email: self.email, password: self.password)
            print("Sign In")
        }catch{
            self.loginStatusMessage = error.localizedDescription
        }
    }
}

struct LogInView: View {
    @ObservedObject var vm = LogInViewModel()
    @Binding var isUserCurrentlyLoggedOut : Bool
    var body: some View {
        
        VStack {
            NavigationStack{
                
                ScrollView{
                    VStack(spacing: 16){
                        TabBarView
                        
                        if !vm.isLoginMode{
                            ImagePickerView
                        }
                        
                        LoginFieldView
                        Text(vm.loginStatusMessage)
                            .foregroundColor(.red)
                        
                    }
                    .padding()
                }
                .navigationTitle(vm.isLoginMode ? "Login" : "Create Account")
                .background(Color(.init(white:0,alpha:0.05))
                    .ignoresSafeArea())
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .onChange(of: vm.imageItem) {
            Task {
                if let loaded = try? await vm.imageItem?.loadTransferable(type: Data.self) {
                    if let imageData = UIImage(data: loaded){
                        vm.imageData = imageData
                    }
                } else {
                    print("Failed to select Image")
                }
            }
        }
        
    }
}


extension LogInView{
    private var ImagePickerView : some View{
        VStack{
            PhotosPicker(selection: $vm.imageItem) {
                VStack{
                    if let image = vm.imageData{
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
            if vm.imageData != nil{
                Button("Remove Image"){
                    vm.imageData = nil
                    vm.imageItem = nil
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
                    checkTheUserIsLoggedIn()

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
            
        }
    }
    private func checkTheUserIsLoggedIn(){
        isUserCurrentlyLoggedOut = !AuthenticationManager.shared.checkIfUserIsAuthenticated()
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

#Preview {
    LogInView(isUserCurrentlyLoggedOut: .constant(true))
}
