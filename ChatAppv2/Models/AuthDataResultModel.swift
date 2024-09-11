//
//  AuthDataResult.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import Foundation
import FirebaseAuth

struct AuthDataResultModel:Hashable{
    let uid : String
    let email : String?
    let photoURL : String?
    
    init(user:User){
        self.email = user.email
        self.uid = user.uid
        self.photoURL = user.photoURL?.absoluteString
    }
    init(uid:String,email:String,photoUrl:String){
        self.uid = uid
        self.email = email
        self.photoURL = photoUrl
    }
}
