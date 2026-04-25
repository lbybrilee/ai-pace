import SwiftUI

struct FlashingDot: View {
    let color: Color
    var shouldPulse: Bool = true
    @State private var isDimmed = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .opacity(isDimmed ? 0.55 : 1.0)
            .scaleEffect(isDimmed ? 0.9 : 1.0)
            .onAppear {
                guard shouldPulse else { return }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
    }
}
