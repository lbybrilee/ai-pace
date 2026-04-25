import SwiftUI

/// Tiny sparkline rendering usage percentage samples over the last 24h.
/// Renders nothing when there's too little data to be meaningful (first boot / first
/// few refreshes), to avoid artifacts from 2-point curves clustered at "now".
struct SparklineView: View {
    let samples: [UsageHistoryStore.Sample]
    let accent: Color
    var height: CGFloat = 14

    /// Smallest timespan (seconds) that justifies drawing a trend line. Below this,
    /// the curve is visually meaningless — all points cluster at the right edge.
    static let minimumSpan: TimeInterval = 15 * 60

    static func hasRenderableData(_ samples: [UsageHistoryStore.Sample]) -> Bool {
        guard let first = samples.first, let last = samples.last, samples.count >= 3 else {
            return false
        }
        return last.timestamp - first.timestamp >= minimumSpan
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard Self.hasRenderableData(samples),
                      let firstSample = samples.first,
                      let lastSample = samples.last
                else { return }

                // Scale x to the actual sample span rather than the whole 24h window.
                // That way a line covering 2h stretches across the canvas legibly.
                let xSpan = max(lastSample.timestamp - firstSample.timestamp, 1)

                let points: [CGPoint] = samples.map { sample in
                    let xFraction = (sample.timestamp - firstSample.timestamp) / xSpan
                    let yFraction = max(0, min(1, sample.percentage / 100))
                    return CGPoint(
                        x: CGFloat(xFraction) * size.width,
                        y: size.height - CGFloat(yFraction) * size.height
                    )
                }

                guard let first = points.first else { return }

                var linePath = Path()
                linePath.move(to: first)
                for point in points.dropFirst() {
                    linePath.addLine(to: point)
                }
                context.stroke(
                    linePath,
                    with: .color(accent.opacity(0.8)),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                )

                if let latest = points.last {
                    let dot = CGRect(x: latest.x - 2, y: latest.y - 2, width: 4, height: 4)
                    context.fill(Path(ellipseIn: dot), with: .color(accent))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}
