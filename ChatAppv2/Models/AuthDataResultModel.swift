//
//  AuthDataResult.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 8/31/24.
//

import Foundation
import FirebaseAuth

struct AuthDataResultModel{
    let uid : String
    let email : String?
    let photoURL : String?
    
    init(user:User){
        self.email = user.email
        self.uid = user.uid
        self.photoURL = user.photoURL?.absoluteString
    }
}
