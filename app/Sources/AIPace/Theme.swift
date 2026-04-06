import SwiftUI

struct AppTheme: Identifiable {
    let id: String
    let name: String
    let claudeAccent: Color
    let codexAccent: Color

    static let sunset = AppTheme(
        id: "sunset", name: "Sunset",
        claudeAccent: Color(red: 0.95, green: 0.45, blue: 0.10),
        codexAccent: Color(red: 0.10, green: 0.50, blue: 0.95)
    )

    static let neon = AppTheme(
        id: "neon", name: "Neon",
        claudeAccent: Color(red: 0.95, green: 0.15, blue: 0.45),
        codexAccent: Color(red: 0.05, green: 0.80, blue: 0.35)
    )

    static let ocean = AppTheme(
        id: "ocean", name: "Ocean",
        claudeAccent: Color(red: 0.92, green: 0.30, blue: 0.25),
        codexAccent: Color(red: 0.0, green: 0.65, blue: 0.75)
    )

    static let forest = AppTheme(
        id: "forest", name: "Forest",
        claudeAccent: Color(red: 0.85, green: 0.55, blue: 0.05),
        codexAccent: Color(red: 0.05, green: 0.65, blue: 0.35)
    )

    static let berry = AppTheme(
        id: "berry", name: "Berry",
        claudeAccent: Color(red: 0.78, green: 0.15, blue: 0.55),
        codexAccent: Color(red: 0.30, green: 0.25, blue: 0.85)
    )

    static let citrus = AppTheme(
        id: "citrus", name: "Citrus",
        claudeAccent: Color(red: 0.92, green: 0.42, blue: 0.0),
        codexAccent: Color(red: 0.35, green: 0.75, blue: 0.05)
    )

    static let arctic = AppTheme(
        id: "arctic", name: "Arctic",
        claudeAccent: Color(red: 0.88, green: 0.28, blue: 0.38),
        codexAccent: Color(red: 0.15, green: 0.55, blue: 0.82)
    )

    static let volcano = AppTheme(
        id: "volcano", name: "Volcano",
        claudeAccent: Color(red: 0.88, green: 0.18, blue: 0.12),
        codexAccent: Color(red: 0.85, green: 0.65, blue: 0.0)
    )

    static let aurora = AppTheme(
        id: "aurora", name: "Aurora",
        claudeAccent: Color(red: 0.55, green: 0.25, blue: 0.90),
        codexAccent: Color(red: 0.05, green: 0.72, blue: 0.48)
    )

    static let mono = AppTheme(
        id: "mono", name: "Mono",
        claudeAccent: Color(red: 0.55, green: 0.50, blue: 0.45),
        codexAccent: Color(red: 0.40, green: 0.48, blue: 0.55)
    )

    static let all: [AppTheme] = [
        .sunset, .neon, .ocean, .forest, .berry,
        .citrus, .arctic, .volcano, .aurora, .mono,
    ]

    static let defaultTheme = sunset

    static func find(_ id: String) -> AppTheme {
        all.first { $0.id == id } ?? defaultTheme
    }
}
