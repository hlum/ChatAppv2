//
//  DBUser.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import Foundation
import FirebaseCore

struct DBUser:Identifiable, Codable , Hashable {
    var id: String = UUID().uuidString
    let userId : String
    let name :String?
    let email : String?
    let photoUrl : String?
    let dateCreated : Timestamp?
    let preferences:[String]?
    let age : Double?
    let chatIds:[String]
    
    init(id:String,userId:String,name:String,email:String,photoUrl:String,dateCreated:Timestamp,preferences:[String],age:Double,chatIds:[String]){
        self.id = id
        self.userId = userId
        self.name = name
        self.email = email
        self.photoUrl = photoUrl
        self.dateCreated = dateCreated
        self.preferences = preferences
        self.age = age
        self.chatIds = chatIds
    }
    
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
            if recentMessage.senderEmail == currentUser.email{
                return recentMessage.recipientProfileUrl
            }else{
                return recentMessage.senderProfileUrl
            }
        }()
        self.dateCreated = recentMessage.dateCreated
        self.preferences = nil
        self.name = {
            if recentMessage.senderEmail == currentUser.email{
                return recentMessage.recieverName
            }else{
                return recentMessage.senderName
            }
        }()
        self.age = 0
        self.chatIds = []
    }
    
    init(data:[String:Any]){
        self.userId = data[CodingKeys.userId.rawValue] as? String ?? ""
        self.email = data[CodingKeys.email.rawValue] as? String ?? ""
        self.photoUrl = data[CodingKeys.photoUrl.rawValue] as? String ?? ""
        self.dateCreated = data[CodingKeys.dateCreated.rawValue] as? Timestamp ?? Timestamp(date: Date())
        self.preferences = data[CodingKeys.preferences.rawValue] as? [String] ?? []
        self.age = data[CodingKeys.age.rawValue] as? Double ?? 18
        self.name = data[CodingKeys.name.rawValue] as? String ?? ""
        self.chatIds = data[CodingKeys.chatIds.rawValue] as? [String] ?? []
    }
    
    init(authDataResult : AuthDataResultModel,photoUrl:String?,preferences:[String],name:String,age:Double){
        self.userId = authDataResult.uid
        self.email = authDataResult.email
        self.photoUrl = photoUrl?.description
        self.dateCreated = Timestamp(date: Date())
        self.preferences = preferences
        self.name = name
        self.age = age
        self.chatIds = []
    }

    
    init(authDataResult : AuthDataResultModel){
        self.userId = authDataResult.uid
        self.email = authDataResult.email
        self.photoUrl = authDataResult.photoURL?.description
        self.dateCreated = Timestamp(date: Date())
        self.preferences = nil
        self.name = nil
        self.age = nil
        self.chatIds = []
    }
    
    init(
        userId:String,
        email:String? = nil,
        photoUrl:String? = nil,
        dateCreated:Timestamp? = nil,
        preferences:[String]? = nil
    ){
        self.userId = userId
        self.email = email
        self.photoUrl = photoUrl
        self.dateCreated = dateCreated
        self.preferences = []
        self.name = nil
        self.age = nil
        self.chatIds = []
    }
    
    enum CodingKeys:String, CodingKey {
        case userId = "user_id"
        case email = "email"
        case photoUrl = "photo_url"
        case dateCreated = "date_created"
        case preferences = "preferences"
        case age = "age"
        case name = "name"
        case chatIds = "chat_ids"
    }
    
    init(from decoder: Decoder) throws {
         let container = try decoder.container(keyedBy: CodingKeys.self)
         self.id = try container.decode(String.self, forKey: .userId) // Use userId as id
         self.userId = try container.decode(String.self, forKey: .userId)
         self.name = try container.decodeIfPresent(String.self, forKey: .name)
         self.email = try container.decodeIfPresent(String.self, forKey: .email)
         self.photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        self.dateCreated = try container.decodeIfPresent(Timestamp.self, forKey: .dateCreated)
         self.preferences = try container.decodeIfPresent([String].self, forKey: .preferences)
         self.age = try container.decodeIfPresent(Double.self, forKey: .age)
        self.chatIds = try container.decodeIfPresent([String].self, forKey: .chatIds) ?? []
     }
     
     func encode(to encoder: Encoder) throws {
         var container = encoder.container(keyedBy: CodingKeys.self)
         try container.encode(self.userId, forKey: .userId)
         try container.encodeIfPresent(self.name, forKey: .name)
         try container.encodeIfPresent(self.email, forKey: .email)
         try container.encodeIfPresent(self.photoUrl, forKey: .photoUrl)
         try container.encodeIfPresent(self.dateCreated, forKey: .dateCreated)
         try container.encodeIfPresent(self.preferences, forKey: .preferences)
         try container.encodeIfPresent(self.age, forKey: .age)
         try container.encodeIfPresent(self.chatIds, forKey: .chatIds)
     }
    
}

