//
//  MessageModel.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import Foundation
import FirebaseFirestore

struct FirebaseConstants{
    static let fromId = "from_id"
    static let toId = "to_id"
    static let text = "text"
    static let dateCreated = "date_created"
    static let profileImageUrl = "photo_url"
    static let recipientProfileUrl = "recipient_profile_url"
    static let senderEmail = "email"
    static let recipientEmail = "recipient_email"
}


struct MessageModel:Identifiable, Codable,Hashable{
    var id :String = UUID().uuidString
    let documentId :String
    let fromId,toId,text: String
    let dateCreated : Timestamp
    let profileImageUrl: String
    let recipientProfileUrl: String
    let recipientEmail:String
    let senderEmail:String
    
    init(
        id:String,
        documentId:String,
        fromId:String,
        toId:String,
        text:String,
        dateCreated:Timestamp,
        profileImageUrl:String,
        recipientProfileUrl:String,
        recipientEmail:String,
        senderEmail:String
    ){
        self.id = id
        self.documentId = documentId
        self.fromId = fromId
        self.toId = toId
        self.text = text
        self.dateCreated = dateCreated
        self.profileImageUrl = profileImageUrl
        self.recipientEmail = recipientEmail
        self.recipientProfileUrl = recipientProfileUrl
        self.senderEmail = senderEmail
    }
    
    init(documentId:String,data:[String:Any]) {
        self.documentId = documentId
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
        self.dateCreated = data[FirebaseConstants.dateCreated] as? Timestamp ?? Timestamp()
        self.profileImageUrl = data[FirebaseConstants.profileImageUrl] as? String ?? ""
        self.recipientProfileUrl = data[FirebaseConstants.recipientProfileUrl] as? String ?? ""
        self.recipientEmail = data[FirebaseConstants.recipientEmail] as? String ?? ""
        self.senderEmail = data[FirebaseConstants.senderEmail] as? String ?? ""
    }
    
    enum CodingKeys:String, CodingKey {
        case id = "id"
        case documentId = "document_id"
        case fromId = "from_id"
        case toId = "to_id"
        case text = "text"
        case dateCreated = "date_created"
        case profileImageUrl = "profile_image_url"
        case recipientProfileUrl = "recipient_profile_url"
        case recipientEmail = "recipient_email"
        case senderEmail = "sender_email"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.documentId = try  container.decode(String.self, forKey: .documentId)
        self.fromId = try container.decode(String.self, forKey: .fromId)
        self.toId = try container.decode(String.self, forKey: .toId)
        self.text = try container.decode(String.self, forKey: .text)
        self.dateCreated = try container.decode(Timestamp.self, forKey: .dateCreated)
        self.profileImageUrl = try container.decode(String.self, forKey: .profileImageUrl)
        self.recipientProfileUrl = try container.decode(String.self, forKey: .recipientProfileUrl)
        self.recipientEmail = try container.decode(String.self, forKey: .recipientEmail)
        self.senderEmail = try container.decode(String.self, forKey: .senderEmail)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.documentId, forKey: .documentId)
        try container.encode(self.fromId, forKey: .fromId)
        try container.encode(self.toId, forKey: .toId)
        try container.encode(self.text, forKey: .text)
        try container.encode(self.dateCreated, forKey: .dateCreated)
        try container.encode(self.profileImageUrl, forKey: .profileImageUrl)
        try container.encode(self.recipientProfileUrl, forKey: .recipientProfileUrl)
        try container.encode(self.recipientEmail, forKey: .recipientEmail)
        try container.encode(self.senderEmail, forKey: .senderEmail)
    }

}
