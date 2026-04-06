import SwiftUI

struct AppLogoView: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.10, blue: 0.17),
                            Color(red: 0.12, green: 0.16, blue: 0.25),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: size * 0.02)

            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: size * 0.065)
                .frame(width: size * 0.54, height: size * 0.54)

            GaugeArc(startAngle: .degrees(144), endAngle: .degrees(262))
                .stroke(
                    Color(red: 0.95, green: 0.45, blue: 0.10),
                    style: StrokeStyle(lineWidth: size * 0.14, lineCap: .round)
                )
                .frame(width: size * 0.72, height: size * 0.72)

            GaugeArc(startAngle: .degrees(-42), endAngle: .degrees(78))
                .stroke(
                    Color(red: 0.10, green: 0.50, blue: 0.95),
                    style: StrokeStyle(lineWidth: size * 0.14, lineCap: .round)
                )
                .frame(width: size * 0.72, height: size * 0.72)

            Capsule(style: .continuous)
                .fill(Color.white)
                .frame(width: size * 0.10, height: size * 0.34)
                .offset(y: -size * 0.12)
                .rotationEffect(.degrees(38))
                .shadow(color: Color.black.opacity(0.18), radius: size * 0.03, y: size * 0.01)

            Circle()
                .fill(Color.white)
                .frame(width: size * 0.18, height: size * 0.18)
                .shadow(color: Color.black.opacity(0.16), radius: size * 0.02, y: size * 0.01)
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }
}

private struct GaugeArc: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) * 0.5,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
