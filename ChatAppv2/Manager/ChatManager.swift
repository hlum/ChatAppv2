//
//  ChatManager.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 9/21/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class ChatManager {
    static let shared = ChatManager()
    
    private init(){}
    
    //Encoder and Decoder for Firestore
    private let encoder:Firestore.Encoder = {
        let encoder = Firestore.Encoder()
        return encoder
    }()
    
    
    private let decoder : Firestore.Decoder = {
        let decoder = Firestore.Decoder()
        return decoder
    }()

    //Firestore Collection
    private let userCollection = Firestore.firestore().collection("users")
    
    private func userDocuments(userId:String) -> DocumentReference{
        userCollection.document(userId)
    }

    private func chatDocuments(chatId:String)->DocumentReference{
        Firestore.firestore().collection("chat_messages").document(chatId)
    }
    
    let recentMessagesCollection = Firestore.firestore().collection("recentMessages")

    
    func sendMessage(message:MessageModel,recipientId:String,userId:String) async{
        let chatId = IdGenerator.shared.generateUnionId(userId, recipientId)
        do {
            try chatDocuments(chatId: chatId)
                .collection("messages")
                .document(message.id)
                .setData(from: message.self, encoder: encoder)
            await self.storeRecentMessages(message: message)
                

        } catch {
            print("Error writing message to Firestore: \(error)")
        }
    }
    
    
    func getMessages(userId:String,recipientId:String,completion:@escaping (MessageModel,DocumentChangeType)->()){
        let chatId = IdGenerator.shared.generateUnionId(userId, recipientId)
        chatDocuments(chatId: chatId)
            .collection("messages")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching messages: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("No messages found")
                    return
                }
                
                snapshot.documentChanges.forEach { change in
                    let data = change.document.data()
                    guard let message = try? self.decoder.decode(MessageModel.self, from: data) else {
                        print("Failed to decode message")
                        return
                    }
                    
                    switch change.type {
                    case .added:
                        completion(message, .added)
                    case .modified:
                        completion(message, .modified)
                    case .removed:
                        completion(message, .removed)
                    }
                    
                }
            }
    }
}


extension ChatManager{
    
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
            recipientProfileUrl: message.senderProfileUrl,
            recipientEmail: message.senderEmail,
            senderEmail: message.recipientEmail,
            senderProfileUrl: message.recipientProfileUrl,
            senderName: message.recieverName,
            recieverName : message.senderName
        )
        
        do {
            
            try documentForRecipient.setData(from: dataForRecipient,encoder: encoder)
        } catch{
            print("UserManager/getMessages:Error storing message: \(error.localizedDescription)")
        }
    }
}
