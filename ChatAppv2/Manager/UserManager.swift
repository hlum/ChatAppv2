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
                let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            }
            
            
            //get the download url
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
                if user.userId != AuthenticationManager.shared.currentUser?.uid{
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


//Messages features
extension UserManager{
    
    func storeMessages(message:MessageModel)async{
        let document = messagesCollection
            .document(message.fromId)
            .collection(message.toId)
            .document(message.id)
        do {
            try document.setData(from: message,encoder: encoder)
        } catch {
            print("Error storing message: \(error.localizedDescription)")
        }
        
        let documentForRecipient = messagesCollection
                .document(message.toId)
                .collection(message.fromId)
                .document(message.id)
        
        let messageForRecipient = MessageModel(
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
            senderName: message.senderName,
            recieverName : message.senderName,
            isUnread: true
        )

        do {
            try documentForRecipient.setData(from: messageForRecipient,encoder: encoder)
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
            recieverName : message.senderName,
            isUnread: true
        )
        
        do {
            
            try documentForRecipient.setData(from: dataForRecipient,encoder: encoder)
        } catch{
            print("UserManager/getMessages:Error storing message: \(error.localizedDescription)")
        }

    }
    

    
    // UserManager.swift
    func getMessages(fromId: String, toId: String, completion: @escaping (MessageModel, DocumentChangeType) -> Void) -> ListenerRegistration {
        return messagesCollection
            .document(fromId)
            .collection(toId)
            .order(by: FirebaseConstants.dateCreated)
            .addSnapshotListener { snapshots, error in
                if let error = error {
                    print("Error fetching messages: \(error.localizedDescription)")
                    return
                }
                
                snapshots?.documentChanges.forEach({ change in
                    let data = change.document.data()
                    let chatMessage = MessageModel(documentId: change.document.documentID, data: data)
                    
                    switch change.type {
                    case .added:
                        completion(chatMessage, .added)
                    case .modified:
                        completion(chatMessage, .modified)
                    case .removed:
                        completion(chatMessage, .removed)
                    }
                })
            }
    }
    
    
    func getLastReadMessage(userId: String, chatPartnerId: String, completion: @escaping (String?) -> Void) -> ListenerRegistration {
        return messagesCollection
            .document(userId)
            .collection(chatPartnerId)
            .whereField(FirebaseConstants.isUnread, isEqualTo: false)
            .order(by: FirebaseConstants.dateCreated, descending: true)
            .limit(to: 1)

            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents,
                      !documents.isEmpty else {
                    print("No read messages found or error: \(error?.localizedDescription ?? "Unknown error")")
                    completion(nil)
                    return
                }
                
                let lastMessageId = documents[0].documentID
                completion(lastMessageId)
            }
    }

    func markMessageAsRead(userId: String, chatPartnerId: String, messageId: String) async throws {
        let messageRef = messagesCollection
            .document(userId)
            .collection(chatPartnerId)
            .document(messageId)

        try await messageRef.updateData([FirebaseConstants.isUnread: false])
    }


    
    func markAllMessagesAsRead(userId: String, chatPartnerId: String) async throws {
        let reference = recentMessagesCollection
            .document(userId)
            .collection("messages")
            .document(chatPartnerId)

        try await reference.updateData([FirebaseConstants.isUnread: false])
        
        // Also update all individual messages
        let messagesRef = messagesCollection
            .document(userId)
            .collection(chatPartnerId)
        
        let query = messagesRef.whereField(FirebaseConstants.isUnread, isEqualTo: true)
        let snapshot = try await query.getDocuments()
        
        for document in snapshot.documents {
            try await document.reference.updateData([FirebaseConstants.isUnread: false])
        }
    }
    
    
    


}


