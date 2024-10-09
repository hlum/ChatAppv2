//
//  LottieView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 10/4/24.
//

import Lottie
import SwiftUI

struct LottieView:UIViewRepresentable{
    
    var animationFileName:String
    let loopMode:LottieLoopMode
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
    }
    
    func makeUIView(context: Context) -> Lottie.LottieAnimationView {
        let animationView = LottieAnimationView(name:animationFileName)
        animationView.loopMode = loopMode
        
        animationView.play()
        animationView.contentMode = .scaleAspectFit
        return animationView
        
    }
}
