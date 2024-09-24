//
//  MessageView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 9/17/24.
//

import SwiftUI
import FirebaseCore
import SDWebImageSwiftUI

struct MessageView: View {
    let message: MessageModel
    let isFromCurrentUser: Bool
    
    var body: some View {
            if isFromCurrentUser {
                
                HStack{
                    Spacer()
                    Text(message.text)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }.padding(.horizontal)
            }else{
                HStack{
                    WebImage(url: URL(string: message.senderProfileUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    } placeholder: {
                        Image(.profilePic)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    }

                        
                    Text(message.text)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    
                    Spacer()
                }.padding(.horizontal)
            }
        
    }
}


#Preview{
    MessageView(
        message: MessageModel(
            id: "123", documentId: "123",
            fromId: "123",
            toId: "456",
            text: "Hello, how are you?",
            dateCreated: Timestamp(),
            recipientProfileUrl: "https://picsum.photos/200",
            recipientEmail: "",
            senderEmail: "",
            senderProfileUrl: "https://picsum.photos/200",
            senderName: "John Doe",
            recieverName: "Jane Doe"
        ),
        isFromCurrentUser: false
    )
}
