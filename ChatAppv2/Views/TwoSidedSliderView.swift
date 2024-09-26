import SwiftUI


struct AgeRangeView:View {
    @Binding var initialAge:Double
    @Binding var finalAge:Double
    var body: some View {
        VStack{
            HStack{
                Text("\(Int(initialAge))歳")
                Slider(value: $initialAge, in:(18...100))
            }
            HStack{
                Text("\(Int(finalAge))歳")
                Slider(value: $finalAge, in:(18...100))
            }
        }
        .padding()
    }
}
#Preview {
    AgeRangeView(initialAge: .constant(18), finalAge: .constant(100))
}
