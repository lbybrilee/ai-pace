import AppKit
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

    /// Official brand marks for each provider:
    /// - Claude → `#D97757` — Anthropic's signature orange (same fill used in the
    ///   official Claude SVG symbol, listed in their brand palette as the accent
    ///   orange).
    /// - Codex → `#0F0F0F` — OpenAI's mark is pure black `#000000`, but pure black
    ///   renders as a near-invisible pill on a dark menu bar. `#0F0F0F` is the
    ///   near-black OpenAI uses on their site chrome; it stays faithful to the
    ///   monochrome brand while keeping the pill distinguishable from the bar.
    static let brand = AppTheme(
        id: "brand", name: "Original",
        claudeAccent: Color(red: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0),
        codexAccent: Color(red: 0x0F / 255.0, green: 0x0F / 255.0, blue: 0x0F / 255.0)
    )

    static let all: [AppTheme] = [
        .brand,
        .sunset, .neon, .ocean, .forest, .berry,
        .citrus, .arctic, .volcano, .aurora, .mono,
    ]

    static let defaultTheme = sunset
    static let customClaudeAccentDefaultsKey = "customClaudeAccentHex"
    static let customCodexAccentDefaultsKey = "customCodexAccentHex"

    static func find(_ id: String) -> AppTheme {
        all.first { $0.id == id } ?? defaultTheme
    }

    func overriding(claudeAccent: Color? = nil, codexAccent: Color? = nil) -> AppTheme {
        AppTheme(
            id: id,
            name: name,
            claudeAccent: claudeAccent ?? self.claudeAccent,
            codexAccent: codexAccent ?? self.codexAccent
        )
    }

    static func resolvedTheme(themeID: String, userDefaults: UserDefaults = .standard) -> AppTheme {
        resolvedTheme(
            themeID: themeID,
            customClaudeAccentHex: userDefaults.string(forKey: customClaudeAccentDefaultsKey),
            customCodexAccentHex: userDefaults.string(forKey: customCodexAccentDefaultsKey)
        )
    }

    static func resolvedTheme(
        themeID: String,
        customClaudeAccentHex: String?,
        customCodexAccentHex: String?
    ) -> AppTheme {
        find(themeID).overriding(
            claudeAccent: AppColorHex.color(from: customClaudeAccentHex),
            codexAccent: AppColorHex.color(from: customCodexAccentHex)
        )
    }
}

extension Color {
    /// Perceived luminance (Rec. 601) in the 0…1 range. Used to detect accents
    /// that are too dark to read without extra help — currently the near-black
    /// Codex mark in the "Original" theme, but any sufficiently dark custom
    /// accent gets the same treatment automatically.
    var estimatedLuminance: Double {
        guard let srgb = NSColor(self).usingColorSpace(.sRGB) else {
            return 0.5
        }
        return 0.299 * Double(srgb.redComponent)
             + 0.587 * Double(srgb.greenComponent)
             + 0.114 * Double(srgb.blueComponent)
    }

    /// Accent color adjusted for legibility against the popover's dark material
    /// card (`.regularMaterial` renders around `#2A2A2A` in dark mode). Near-black
    /// accents get lifted to a graphite mid-tone so the provider dot, usage bar,
    /// and sparkline all stay visible — while still reading as "dark monochrome"
    /// rather than a colored accent. Brighter accents pass through unchanged.
    var liftedForDarkBackground: Color {
        guard estimatedLuminance < 0.18 else { return self }
        return Color(white: 0.52)
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
