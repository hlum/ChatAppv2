//
//  UnionIdGenerator.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 9/15/24.
//

import Foundation


class IdGenerator{
    static let shared = IdGenerator()
    
    private init(){}
    
    func generateUnionId(_ firstId :String, _ lastId: String) -> String{
        let ids = [firstId,lastId]
        guard let first = ids.min(),
              let last = ids.max() else{
            print("Error generating Union Id")
            return ""
        }
        return first + last
    }
}
