//
//  FirebaseManager.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import Foundation
import Firebase
import FirebaseAuth


final class AuthenticationManager: ObservableObject{
    @Published var currentUser : AuthDataResultModel? = nil
    static let shared = AuthenticationManager()
    
    private init(){
        self.currentUser = try? getAuthenticatedUser()
    }
        
    func getAuthenticatedUser() throws -> AuthDataResultModel{
        guard let user = Auth.auth().currentUser else{
            print("No user found")
            throw URLError(.secureConnectionFailed)
        }
            return AuthDataResultModel(user: user)
    }
    
    func signOut(){
        do{
            try Auth.auth().signOut()
        }catch{
            print("Can't Sign Out")
            print(error.localizedDescription)
        }
    }
    
    func deleteUser()async throws{
        guard let user = Auth.auth().currentUser else{ return }
        do {
            try await user.delete()
        }catch{
            print(error.localizedDescription)
        }
    }
    
    func checkIfUserIsAuthenticated() -> Bool{
        return Auth.auth().currentUser != nil
    }
}


extension AuthenticationManager{
        
    @discardableResult
    func createNewUser(email:String,password:String)async throws -> AuthDataResultModel{
        let authDataResult = try await Auth.auth().createUser(withEmail: email, password: password)
        
        let result = AuthDataResultModel(user: authDataResult.user)
        
        return result
    }
    
    @discardableResult
    
    func signIn(email:String,password:String)async throws -> AuthDataResultModel{
        let authDataResult = try await Auth.auth().signIn(withEmail: email,password: password)
        return AuthDataResultModel(user: authDataResult.user)
    }
    
    func resetPassword(email:String)async throws{
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
}
