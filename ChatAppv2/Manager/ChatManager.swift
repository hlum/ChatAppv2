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
    
    
    func sendMessage(message:MessageModel,recipientId:String,userId:String){
        let chatId = IdGenerator.shared.generateUnionId(userId, recipientId)
        let data:[String:Any] = [
            "chat_ids":FieldValue.arrayUnion([chatId])
        ]
        userDocuments(userId: userId).updateData(data)
        
        do {
            try chatDocuments(chatId: chatId).setData(from: message.self,encoder: encoder)

        } catch {
            print("Error writing message to Firestore: \(error)")
        }
    }
    
    
    func getMessages(userId:String,recipientId:String,completion:@escaping ([MessageModel])->()){
        let chatId = IdGenerator.shared.generateUnionId(userId, recipientId)
        
        chatDocuments(chatId: chatId)
            .collection("messages")
            .order(by: "timestamp",descending: false)
            .getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("No documents found")
                return
            }
            let messages = documents.compactMap { document in
                try? self.decoder.decode(MessageModel.self, from: document.data())
            }
            completion(messages)
        }
    }
    
}
