//
//  OtherUserView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 9/25/24.
//

import SwiftUI
import FirebaseCore
import SDWebImageSwiftUI

final class OtherUserViewModel:ObservableObject{
    @Published var matchLevel : Int = 0
    @Published var otherUser:DBUser
    @Published var user : DBUser
    
    
    init(user:DBUser,otherUser:DBUser){
        self.user = user
        self.otherUser = otherUser
        getMatchLevel()
    }
    
    func getMatchLevel(){
        let othersPreferences = otherUser.preferences
        let userPreferences = user.preferences
        for userPreference in userPreferences{
            if othersPreferences.contains(userPreference){
                if matchLevel < 8{
                    matchLevel += 1
                }
            }
        }
    
    }
}

struct OtherUserView: View {
    @StateObject var vm : OtherUserViewModel
    
    init(user:DBUser,otherUser:DBUser){
        _vm = StateObject(wrappedValue: OtherUserViewModel(user: user,otherUser: otherUser))
    }
    var body: some View {
        
        ZStack{
            HStack{
                profilePic
                    .padding(.horizontal)
                nameAndAge
                Spacer()

            }
            .frame(maxWidth: 200)
            .frame(height: 80)
            .background(.customWhite)
            .cornerRadius(10)
            
            
            HStack{
                ForEach(0..<vm.matchLevel, id:\.self){ _ in
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color.pink)
                        .offset(y:-10)
                }
            }
            .offset(y:-30)

        }
    }
}

extension OtherUserView{
    private var profilePic : some View{
        VStack{
            let url = URL(string: vm.otherUser.photoUrl ?? "")
            WebImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.white), lineWidth: 4)
                    )
                    .shadow(color: .gray.opacity(0.4), radius: 10, x: 0, y: 5)
            } placeholder: {
                Image(.profilePic)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.white), lineWidth: 4)
                    )
                    .shadow(color: .gray.opacity(0.4), radius: 10, x: 0, y: 5)
            }
        }
    }
    private var nameAndAge : some View{
        VStack(alignment: .leading){
            Text(vm.otherUser.name ?? "")
                .lineLimit(1)
                .font(.system(size: 20,weight: .bold))
                .foregroundStyle(Color.black)
            Text("\(Int(vm.otherUser.age ?? 0))歳")
                .font(.system(size: 15))
                .foregroundStyle(Color.gray)
        }
    }
}

#Preview {
    let currentUser = DBUser(
        id: "",
        userId: "",
        name: "user",
        email: "user@gmail.com",
        photoUrl: "https://cdn.pixabay.com/photo/2018/11/13/22/01/avatar-3814081_640.png",
        dateCreated: Timestamp(date: Date()),
        preferences: ["1","2","3","4"],
        age: 17,
        chatIds: []
    )
    
    OtherUserView(
        user:currentUser,
        otherUser:DBUser(
            id: "",
            userId: "",
            name: "asdfsadfadsf",
            email: "hlum@gmail.com",
            photoUrl: "https://cdn.pixabay.com/photo/2018/11/13/22/01/avatar-3814081_640.png",
            dateCreated: Timestamp(date: Date()),
            preferences: ["1","2","3","4"],
            age: 13,
            chatIds: []
        )
    )
}
