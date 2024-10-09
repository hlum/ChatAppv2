//
//  SplashView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 10/4/24.
//

import SwiftUI

struct SplashView: View {
    @Binding var isAvtive:Bool
    var body: some View {
        ZStack{
            if self.isAvtive{
                MainTabView()
            }else{
                ZStack{
                    Color.white.ignoresSafeArea()
                    LottieView(animationFileName: "dancing_cat", loopMode: .loop)
                }
                .onAppear{
                    DispatchQueue.main.asyncAfter(deadline: .now()+5){
                        withAnimation(.easeIn) {
                            self.isAvtive = true
                        }
                    }
                }
            }
        }
    }
}


