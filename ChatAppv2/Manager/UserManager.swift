//
//  UserManager.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage

struct GoogleSignInResultModel{
    let idToken: String
    let acessToken : String
    let name : String?
    let email : String?
}


final class UserManager{
    static let shared = UserManager()
    private init(){}
    
    private let userCollection = Firestore.firestore().collection("users")
    
    let recentMessagesCollection = Firestore.firestore().collection("recentMessages")
    
    private let messagesCollection = Firestore.firestore().collection("messages")
    
    
    private func userDocuments(userId:String) -> DocumentReference{
        userCollection.document(userId)
    }
    
    private let encoder:Firestore.Encoder = {
        let encoder = Firestore.Encoder()
        return encoder
    }()
    
    private let decoder : Firestore.Decoder = {
        let decoder = Firestore.Decoder()
        return decoder
    }()
    
    @discardableResult
    func saveImageInStorage(image:UIImage,userId:String)async throws -> String{
        
        let reference = Storage.storage().reference(withPath:userId)
        guard let data = image.jpegData(compressionQuality: 0.1) else{
            print("UserManager: Can't convert image to data")
            throw URLError(.unknown)
        }
        
        do{
            //upload the image data
            _ = try await reference.putDataAsync(data, metadata: nil) { progress in
                guard let progress = progress else { return }
                _ = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            }            //get the download url
            
            let downloadUrl = try await reference.downloadURL()
            
            return downloadUrl.absoluteString
        }catch{
            print("Error saving image: \(error.localizedDescription)")
            throw error
        }
    }
    
    func changeNewProfileImageUrl(downloadUrl:String,userId:String){
        let data:[String:Any] = [FirebaseConstants.profileImageUrl:downloadUrl]
        userDocuments(userId: userId).updateData(data)
    }

    
    //this isn't really a async func but writting datas in the database might take some times
    func storeNewUser(user:DBUser) async {
        do{
            try userDocuments(userId: user.userId).setData(from: user,encoder: encoder)
        }catch{
            print("error encountered while storing user:\(error.localizedDescription)")
        }
    }
    
    func getUser(userId:String) async throws-> DBUser{
        do{
            let result = try await  userDocuments(userId: userId).getDocument(as: DBUser.self)
            return result
        }catch{
            print("UserManager/getUser/error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func getAllUsers() async -> [DBUser] {
        var users : [DBUser] = []
        do{
            let snapshot = try await Firestore.firestore().collection("users").getDocuments()
            snapshot.documents.forEach { documentSnapshot in
                let data = documentSnapshot.data()
                let user = DBUser(data: data)
                guard let currentUser = try? AuthenticationManager.shared.getAuthenticatedUser()else{
                    print("UserManager: Can't get current user")
                    return
                }
                if user.userId != currentUser.uid{
                    users.append(user)
                }
            }
        }catch{
            print("UserManger: Error getting all users\(error.localizedDescription)")
        }
        
        return users
    }
    
    func checkIfUserExistInDatabase(userId:String)async throws ->Bool{
        let snapshot = try await Firestore.firestore().collection("users").document(userId).getDocument()
        return snapshot.exists
    }
    
    func addUserPreference(userId:String,preference:String)async throws{
        let data:[String:Any] = [
            DBUser.CodingKeys.preferences.rawValue: FieldValue.arrayUnion([preference])
        ]
        
        try await userDocuments(userId: userId).updateData(data)
    }
    
    func removeUserPreference(userId:String,preference:String)async throws{
        let data:[String:Any] = [
            DBUser.CodingKeys.preferences.rawValue : FieldValue.arrayRemove([preference])
        ]
        try await userDocuments(userId: userId).updateData(data)
    }
    
    func updateUserName(userId:String,name:String)async throws{
        let newData:[String:Any] = ["name":name]
        try await userDocuments(userId: userId).updateData(newData)
    }
    
}


