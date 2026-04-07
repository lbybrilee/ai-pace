import AppKit
import SwiftUI

struct AppTheme: Identifiable {
    let id: String
    let name: String
    let claudeAccent: Color
    let codexAccent: Color
    let copilotAccent: Color

    static let sunset = AppTheme(
        id: "sunset", name: "Sunset",
        claudeAccent: Color(red: 0.95, green: 0.45, blue: 0.10),
        codexAccent: Color(red: 0.10, green: 0.50, blue: 0.95),
        copilotAccent: Color(red: 0.15, green: 0.58, blue: 0.42)
    )

    static let neon = AppTheme(
        id: "neon", name: "Neon",
        claudeAccent: Color(red: 0.95, green: 0.15, blue: 0.45),
        codexAccent: Color(red: 0.05, green: 0.80, blue: 0.35),
        copilotAccent: Color(red: 0.95, green: 0.72, blue: 0.18)
    )

    static let ocean = AppTheme(
        id: "ocean", name: "Ocean",
        claudeAccent: Color(red: 0.92, green: 0.30, blue: 0.25),
        codexAccent: Color(red: 0.0, green: 0.65, blue: 0.75),
        copilotAccent: Color(red: 0.13, green: 0.52, blue: 0.38)
    )

    static let forest = AppTheme(
        id: "forest", name: "Forest",
        claudeAccent: Color(red: 0.85, green: 0.55, blue: 0.05),
        codexAccent: Color(red: 0.05, green: 0.65, blue: 0.35),
        copilotAccent: Color(red: 0.18, green: 0.43, blue: 0.23)
    )

    static let berry = AppTheme(
        id: "berry", name: "Berry",
        claudeAccent: Color(red: 0.78, green: 0.15, blue: 0.55),
        codexAccent: Color(red: 0.30, green: 0.25, blue: 0.85),
        copilotAccent: Color(red: 0.12, green: 0.57, blue: 0.43)
    )

    static let citrus = AppTheme(
        id: "citrus", name: "Citrus",
        claudeAccent: Color(red: 0.92, green: 0.42, blue: 0.0),
        codexAccent: Color(red: 0.35, green: 0.75, blue: 0.05),
        copilotAccent: Color(red: 0.0, green: 0.49, blue: 0.57)
    )

    static let arctic = AppTheme(
        id: "arctic", name: "Arctic",
        claudeAccent: Color(red: 0.88, green: 0.28, blue: 0.38),
        codexAccent: Color(red: 0.15, green: 0.55, blue: 0.82),
        copilotAccent: Color(red: 0.24, green: 0.62, blue: 0.42)
    )

    static let volcano = AppTheme(
        id: "volcano", name: "Volcano",
        claudeAccent: Color(red: 0.88, green: 0.18, blue: 0.12),
        codexAccent: Color(red: 0.85, green: 0.65, blue: 0.0),
        copilotAccent: Color(red: 0.23, green: 0.50, blue: 0.30)
    )

    static let aurora = AppTheme(
        id: "aurora", name: "Aurora",
        claudeAccent: Color(red: 0.55, green: 0.25, blue: 0.90),
        codexAccent: Color(red: 0.05, green: 0.72, blue: 0.48),
        copilotAccent: Color(red: 0.98, green: 0.68, blue: 0.20)
    )

    static let mono = AppTheme(
        id: "mono", name: "Mono",
        claudeAccent: Color(red: 0.55, green: 0.50, blue: 0.45),
        codexAccent: Color(red: 0.40, green: 0.48, blue: 0.55),
        copilotAccent: Color(red: 0.38, green: 0.56, blue: 0.42)
    )

    static let all: [AppTheme] = [
        .sunset, .neon, .ocean, .forest, .berry,
        .citrus, .arctic, .volcano, .aurora, .mono,
    ]

    static let defaultTheme = sunset
    static let customClaudeAccentDefaultsKey = "customClaudeAccentHex"
    static let customCodexAccentDefaultsKey = "customCodexAccentHex"
    static let customCopilotAccentDefaultsKey = "customCopilotAccentHex"

    static func find(_ id: String) -> AppTheme {
        all.first { $0.id == id } ?? defaultTheme
    }

    func overriding(claudeAccent: Color? = nil, codexAccent: Color? = nil, copilotAccent: Color? = nil) -> AppTheme {
        AppTheme(
            id: id,
            name: name,
            claudeAccent: claudeAccent ?? self.claudeAccent,
            codexAccent: codexAccent ?? self.codexAccent,
            copilotAccent: copilotAccent ?? self.copilotAccent
        )
    }

    static func resolvedTheme(themeID: String, userDefaults: UserDefaults = .standard) -> AppTheme {
        resolvedTheme(
            themeID: themeID,
            customClaudeAccentHex: userDefaults.string(forKey: customClaudeAccentDefaultsKey),
            customCodexAccentHex: userDefaults.string(forKey: customCodexAccentDefaultsKey),
            customCopilotAccentHex: userDefaults.string(forKey: customCopilotAccentDefaultsKey)
        )
    }

    static func resolvedTheme(
        themeID: String,
        customClaudeAccentHex: String?,
        customCodexAccentHex: String?,
        customCopilotAccentHex: String?
    ) -> AppTheme {
        find(themeID).overriding(
            claudeAccent: AppColorHex.color(from: customClaudeAccentHex),
            codexAccent: AppColorHex.color(from: customCodexAccentHex),
            copilotAccent: AppColorHex.color(from: customCopilotAccentHex)
        )
    }
}

enum AppColorHex {
    static func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        let expanded: String
        switch trimmed.count {
        case 3:
            expanded = trimmed.map { "\($0)\($0)" }.joined()
        case 6:
            expanded = trimmed
        default:
            return nil
        }

        guard expanded.allSatisfy(\.isHexDigit) else {
            return nil
        }

        return "#\(expanded)"
    }

    static func color(from value: String?) -> Color? {
        guard let normalized = normalized(value) else {
            return nil
        }

        let hex = String(normalized.dropFirst())
        guard let int = UInt32(hex, radix: 16) else {
            return nil
        }

        let red = Double((int >> 16) & 0xFF) / 255
        let green = Double((int >> 8) & 0xFF) / 255
        let blue = Double(int & 0xFF) / 255
        return Color(red: red, green: green, blue: blue)
    }

    static func string(from color: Color) -> String? {
        let nsColor = NSColor(color)
        guard let srgb = nsColor.usingColorSpace(.sRGB) else {
            return nil
        }

        let red = Int((srgb.redComponent * 255).rounded())
        let green = Int((srgb.greenComponent * 255).rounded())
        let blue = Int((srgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
