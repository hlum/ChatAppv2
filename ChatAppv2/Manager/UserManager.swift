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
                let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                print("Upload is \(percentComplete)% complete")
            }
            
            
            //get the download url
            let downloadUrl = try await reference.downloadURL()
            
            return downloadUrl.absoluteString
        }catch{
            print("Error saving image: \(error.localizedDescription)")
            throw error
        }
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
            print(userId)
            let result = try await  userDocuments(userId: userId).getDocument(as: DBUser.self)
            return result
        }catch{
            print(error.localizedDescription)
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
                if user.userId != AuthenticationManager.shared.currentUser?.uid{
                    users.append(user)
                }
            }
        }catch{
            print("UserManger: Error getting all users\(error.localizedDescription)")
        }
        
        return users
    }
    
    
        
    func storeMessages(message:MessageModel)async{
        let document = messagesCollection
            .document(message.fromId)
            .collection(message.toId)
            .document()
        do {
            try document.setData(from: message,encoder: encoder)
        } catch {
            print("Error storing message: \(error.localizedDescription)")
        }
        
        let documentForRecipient = messagesCollection
                .document(message.toId)
                .collection(message.fromId)
                .document()
        do {
            try documentForRecipient.setData(from: message,encoder: encoder)
        } catch {
            print("UserManager:Error storing message: \(error.localizedDescription)")
        }
        await storeRecentMessages(message: message)
    }
    
    
    func storeRecentMessages(message:MessageModel)async{
        let document = recentMessagesCollection
            .document(message.fromId)
            .collection("messages")
            .document(message.toId)
        
        do {
            try document.setData(from: message,encoder: encoder)
        } catch{
            print("Error storing message: \(error.localizedDescription)")
        }


        let documentForRecipient = recentMessagesCollection
            .document(message.toId)
            .collection("messages")
            .document(message.fromId)
        
        let dataForRecipient = MessageModel(
            id: message.id,
            documentId: message.id,
            fromId: message.fromId,
            toId: message.toId,
            text: message.text,
            dateCreated: message.dateCreated,
            recipientProfileUrl: message.senderProfileUrl,//change later
            recipientEmail: message.senderEmail,
            senderEmail: message.recipientEmail,
            senderProfileUrl: message.recipientProfileUrl,
            senderName: message.recieverName,
            recieverName : message.recieverName
        )
        
        do {
            
            try documentForRecipient.setData(from: dataForRecipient,encoder: encoder)
        } catch{
            print("UserManager/getMessages:Error storing message: \(error.localizedDescription)")
        }

    }
    

    
    // UserManager.swift

    func getMessages(fromId: String?, toId: String?, completion: @escaping (MessageModel) -> Void) {
        guard let fromId = fromId else {
            print("UserManager/getMessages:No fromId provided")
            return
        }
        guard let toId = toId else {
            print("UserManager/getMessages:No toId provided")
            return
        }
    
        messagesCollection
            .document(fromId)
            .collection(toId)
            .order(by: FirebaseConstants.dateCreated)
            .addSnapshotListener { snapshots, error in
                if let error = error {
                    print("Error fetching messages: \(error.localizedDescription)")
                    return
                }
                
                snapshots?.documentChanges.forEach({ change in
                    if change.type == .added {
                        let data = change.document.data()
                        let chatMessage = MessageModel(documentId: change.document.documentID, data: data)
                        completion(chatMessage) // Pass one message at a time
                    }
                })
            }
    }
    
    func checkIfUserExistInDatabase(userId:String)async throws ->Bool{
        let snapshot = try await Firestore.firestore().collection("users").document(userId).getDocument()
        return snapshot.exists
    }
    
    func addUserPreference(userId:String,preference:[String])async throws{
        let data:[String:Any] = [
            DBUser.CodingKeys.preferences.rawValue: FieldValue.arrayUnion(preference)
        ]
        
        try await userDocuments(userId: userId).updateData(data)
    }
    
}


