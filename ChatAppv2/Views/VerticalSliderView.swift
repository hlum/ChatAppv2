//
//  VerticalSliderView.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 10/2/24.
//

import SwiftUI

/// A vertical slider replicating the iPhone Control Center volume/brightness slider
/// - Parameters:
///     - value: a Binding<Double> to set the value between 0 .. 1 by this slider
///     - onLongPress: an optional closure to call on long press to trigger some action on long press
///     - icon: an optional icon factory to show on this widget
struct VerticalSlider: View {
    @Binding var value: Double
    // Caller can optionally proivde this for long press handling
    var onLongPress: (() -> ())? = nil
    var icon: ((Double) -> Image)? = nil

    // We want the slider to not jump to where the first touch land, just follow drag movement
    // So remember where the slider value is on first touch, then just adjust slider value relative
    // to that value
    @State private var startingValue = 0.0

    // For handling swipe up and down to adjust volume between 0...1
    func gesture1(geometry: GeometryProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0)
        .onEnded { _ in
            self.startingValue = self.value
        }
        .sequenced(before: DragGesture(minimumDistance: 0)
            .onChanged {
                let t = self.startingValue - Double(($0.location.y - $0.startLocation.y) / geometry.size.height)
                self.value = min(max(0.0, t), 1.0)
            }
        )
    }

    // For use when onLongPress handling is set to handle both
    // long press gesture or swiping gesture
    func gesture2(geometry: GeometryProxy) -> some Gesture {
        LongPressGesture(maximumDistance: 0)
        .onEnded { _ in self.onLongPress!() }
        .exclusively(before: gesture1(geometry: geometry))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color(red: 24/255, green: 24/255, blue: 24/255)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                Color(red: 221/255, green: 221/255, blue: 221/255)
                    .frame(width: geometry.size.width, height: geometry.size.height * CGFloat(self.value))
                    .cornerRadius(0)    // must do this, otherwise when the slider gesture reach max the top has rounded corner
                if self.icon != nil {
                    self.icon!(self.value)
                        .font(.system(size: geometry.size.width / 3.0, weight: .regular, design: .default))
                        .foregroundColor(Color(red: 70/255, green: 70/255, blue: 70/255))
                        .offset(y: -geometry.size.height / 5.0)
                        .animation(.easeIn(duration: 1))
                }
            }
            .cornerRadius(geometry.size.width/3.3)
            .gesture(
                self.onLongPress == nil ?
                    AnyGesture(self.gesture1(geometry: geometry).map { _ in () }) :
                    AnyGesture(self.gesture2(geometry: geometry).map { _ in () })
            )
        }
    }
}
