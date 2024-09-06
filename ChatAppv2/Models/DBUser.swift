//
//  DBUser.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import Foundation


struct DBUser:Identifiable, Codable , Hashable {
    let id: String = UUID().uuidString
    let userId : String
    let email : String?
    let photoUrl : String?
    let dateCreated : Date?
    
    
    init(recentMessage:MessageModel,currentUser:DBUser){
        self.userId = {
            if recentMessage.toId == currentUser.userId{
                return recentMessage.fromId
            }else{
                return recentMessage.toId
            }
        }()
        self.email = {
            if recentMessage.senderEmail == currentUser.email{
                return recentMessage.recipientEmail
            }else{
                return recentMessage.senderEmail
            }
        }()
        self.photoUrl = {
            if recentMessage.senderProfileUrl == currentUser.photoUrl{
                return recentMessage.recipientProfileUrl
            }else{
                return recentMessage.senderProfileUrl
            }
        }()
        self.dateCreated = recentMessage.dateCreated
    }
    
    init(data:[String:Any]){
        self.userId = data[CodingKeys.userId.rawValue] as? String ?? ""
        self.email = data[CodingKeys.email.rawValue] as? String ?? ""
        self.photoUrl = data[CodingKeys.photoUrl.rawValue] as? String ?? ""
        self.dateCreated = data[CodingKeys.dateCreated.rawValue] as? Date ?? Date()
    }
    
    init(authDataResult : AuthDataResultModel,photoUrl:String?){
        self.userId = authDataResult.uid
        self.email = authDataResult.email
        self.photoUrl = photoUrl?.description
        self.dateCreated = Date()
    }

    
    init(authDataResult : AuthDataResultModel){
        self.userId = authDataResult.uid
        self.email = authDataResult.email
        self.photoUrl = authDataResult.photoURL?.description
        self.dateCreated = Date()
    }
    
    init(
        userId:String,
        email:String? = nil,
        photoUrl:String? = nil,
        dateCreated:Date? = nil
    ){
        self.userId = userId
        self.email = email
        self.photoUrl = photoUrl
        self.dateCreated = dateCreated
    }
    
    enum CodingKeys:String, CodingKey {
        case userId = "user_id"
        case email = "email"
        case photoUrl = "photo_url"
        case dateCreated = "date_created"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        self.dateCreated = try container.decodeIfPresent(Date.self, forKey: .dateCreated)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.userId, forKey: .userId)
        try container.encodeIfPresent(self.email, forKey: .email)
        try container.encodeIfPresent(self.photoUrl, forKey: .photoUrl)
        try container.encodeIfPresent(self.dateCreated, forKey: .dateCreated)
    }
    
}

