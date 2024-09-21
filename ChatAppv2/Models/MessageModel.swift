//
//  MessageModel.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import Foundation
import FirebaseCore

struct FirebaseConstants{
    static let id = "id"
    static let fromId = "from_id"
    static let toId = "to_id"
    static let text = "text"
    static let dateCreated = "date_created"
    static let profileImageUrl = "photo_url"
    static let recipientProfileUrl = "recipient_profile_url"
    static let senderEmail = "sender_email"
    static let recipientEmail = "recipient_email"
    static let senderProfileUrl = "sender_profile_url"
    static let documentId = "document_id"
    static let senderName = "sender_name"
    static let recieverName = "reciever_name"
    static let lastReadMessageId = "last_read_message_id"
}


struct MessageModel:Identifiable, Codable,Hashable{
    var id :String = UUID().uuidString
    let documentId :String
    let fromId,toId,text: String
    let dateCreated : Timestamp
    let recipientProfileUrl: String
    let recipientEmail:String
    let senderEmail:String
    let senderProfileUrl:String
    let senderName:String
    let recieverName:String
    var isRead:Bool = false
    
    
    var formattedTime: String {
        let date = dateCreated.dateValue()
        return date.formatRelativeTime()
    }
    
    init(
        id:String,
        documentId:String,
        fromId:String,
        toId:String,
        text:String,
        dateCreated:Timestamp,
        recipientProfileUrl:String,
        recipientEmail:String,
        senderEmail:String,
        senderProfileUrl:String,
        senderName:String,
        recieverName : String
    ){
        self.id = id
        self.documentId = id
        self.fromId = fromId
        self.toId = toId
        self.text = text
        self.dateCreated = dateCreated
        self.recipientEmail = recipientEmail
        self.recipientProfileUrl = recipientProfileUrl
        self.senderEmail = senderEmail
        self.senderProfileUrl = senderProfileUrl
        self.senderName = senderName
        self.recieverName = recieverName
    }
    
    //受けたIDは使わない
    init(documentId:String,id:String,data:[String:Any]){
        self.documentId = self.id
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
        self.dateCreated = data[FirebaseConstants.dateCreated] as? Timestamp ?? Timestamp(date: Date())
        self.recipientProfileUrl = data[FirebaseConstants.recipientProfileUrl] as? String ?? ""
        self.recipientEmail = data[FirebaseConstants.recipientEmail] as? String ?? ""
        self.senderEmail = data[FirebaseConstants.senderEmail] as? String ?? ""
        self.senderProfileUrl = data[FirebaseConstants.senderProfileUrl] as? String ?? ""
        self.senderName = data[FirebaseConstants.senderName] as? String ?? ""
        self.recieverName = data[FirebaseConstants.recieverName] as? String ?? ""
    }
    init(documentId:String,data:[String:Any]) {
        self.documentId = documentId
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
        self.dateCreated = data[FirebaseConstants.dateCreated] as? Timestamp ?? Timestamp(date: Date())
        self.recipientProfileUrl = data[FirebaseConstants.recipientProfileUrl] as? String ?? ""
        self.recipientEmail = data[FirebaseConstants.recipientEmail] as? String ?? ""
        self.senderEmail = data[FirebaseConstants.senderEmail] as? String ?? ""
        self.senderProfileUrl = data[FirebaseConstants.senderProfileUrl] as? String ?? ""
        self.senderName = data[FirebaseConstants.senderName] as? String ?? ""
        self.recieverName = data[FirebaseConstants.recieverName] as? String ?? ""
    }
    
    enum CodingKeys:String, CodingKey {
        case id = "id"
        case documentId = "document_id"
        case fromId = "from_id"
        case toId = "to_id"
        case text = "text"
        case dateCreated = "date_created"
        case recipientProfileUrl = "recipient_profile_url"
        case recipientEmail = "recipient_email"
        case senderEmail = "sender_email"
        case senderProfileUrl = "sender_profile_url"
        case senderName = "sender_name"
        case recieverName = "reciever_name"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.documentId = try  container.decode(String.self, forKey: .documentId)
        self.fromId = try container.decode(String.self, forKey: .fromId)
        self.toId = try container.decode(String.self, forKey: .toId)
        self.text = try container.decode(String.self, forKey: .text)
        self.dateCreated = try container.decode(Timestamp.self, forKey: .dateCreated)
        self.recipientProfileUrl = try container.decode(String.self, forKey: .recipientProfileUrl)
        self.recipientEmail = try container.decode(String.self, forKey: .recipientEmail)
        self.senderEmail = try container.decode(String.self, forKey: .senderEmail)
        self.senderProfileUrl = try container.decode(String.self, forKey: .senderProfileUrl)
        self.senderName = try container.decode(String.self, forKey: .senderName)
        self.recieverName = try container.decode(String.self, forKey: .recieverName)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.documentId, forKey: .documentId)
        try container.encode(self.fromId, forKey: .fromId)
        try container.encode(self.toId, forKey: .toId)
        try container.encode(self.text, forKey: .text)
        try container.encode(self.dateCreated, forKey: .dateCreated)
        try container.encode(self.recipientProfileUrl, forKey: .recipientProfileUrl)
        try container.encode(self.recipientEmail, forKey: .recipientEmail)
        try container.encode(self.senderEmail, forKey: .senderEmail)
        try container.encode(self.senderProfileUrl, forKey: .senderProfileUrl)
        try container.encode(self.senderName, forKey: .senderName)
        try container.encode(self.recieverName, forKey: .recieverName)
    }

}


