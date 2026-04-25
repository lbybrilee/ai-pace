import SwiftUI

/// Displays the pacing-coach summary for the 5h window: ETA to cap and a
/// recommended pace when the user is burning faster than the budget.
struct PacingAdviceView: View {
    let advice: PacingAdvice
    let accent: Color

    var body: some View {
        if let line = primaryLine {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(adviceColor)
                Text(line)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(adviceColor)
                if let secondary = secondaryLine {
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(secondary)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var primaryLine: String? {
        if advice.isOverPace, let target = advice.recommendedRatePerHour {
            return "Slow to ~\(formatRate(target))/hr to last to reset"
        }
        if let eta = advice.projectedExhaustion {
            return "ETA to cap: \(formatETA(eta))"
        }
        if let target = advice.recommendedRatePerHour {
            return "Pace ~\(formatRate(target))/hr to last to reset"
        }
        return nil
    }

    private var secondaryLine: String? {
        guard let current = advice.currentRatePerHour else { return nil }
        return "now \(formatRate(current))/hr"
    }

    private var adviceColor: Color {
        advice.isOverPace ? .orange : accent
    }

    private var iconName: String {
        advice.isOverPace ? "exclamationmark.triangle.fill" : "speedometer"
    }

    private func formatRate(_ rate: Double) -> String {
        if rate >= 10 {
            return "\(Int(rate.rounded()))%"
        }
        return String(format: "%.1f%%", rate)
    }

    private func formatETA(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval < 60 {
            return "<1m"
        }
        if interval < 3 * 3600 {
            // Show relative within 3h, easier to act on.
            let totalMinutes = Int((interval / 60).rounded())
            let h = totalMinutes / 60
            let m = totalMinutes % 60
            if h == 0 { return "in \(m)m" }
            return "in \(h)h \(m)m"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
