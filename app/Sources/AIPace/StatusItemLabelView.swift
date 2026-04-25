import AppKit
import SwiftUI

struct StatusItemLabelView: View {
    let claudeText: String?
    let codexText: String?
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 5) {
            if let claudeText {
                pill(logo: ProviderLogo.claude, text: claudeText, color: theme.claudeAccent)
            }
            if let codexText {
                pill(logo: ProviderLogo.codex, text: codexText, color: theme.codexAccent)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
        .allowsHitTesting(false)
    }

    private func pill(logo: NSImage, text: String, color: Color) -> some View {
        // Very dark accents (e.g. the "Original" theme's `#0F0F0F` Codex black) fade
        // into a dark menu bar when treated like a regular colored pill. Detect them
        // by luminance and apply a glossy, slightly lifted treatment that still
        // reads as "black" but has enough dimensional cues (top highlight, brighter
        // border, white halo) to distinguish the capsule from the bar behind it.
        let isDarkAccent = color.estimatedLuminance < 0.18

        let fillGradient = LinearGradient(
            colors: isDarkAccent
                ? [Color(white: 0.24), Color(white: 0.04)]
                : [color.opacity(0.95), color.opacity(0.78)],
            startPoint: .top,
            endPoint: .bottom
        )
        let borderGradient = LinearGradient(
            colors: isDarkAccent
                ? [Color.white.opacity(0.38), Color.white.opacity(0.10)]
                : [Color.white.opacity(0.26), Color.white.opacity(0.08)],
            startPoint: .top,
            endPoint: .bottom
        )
        let shadowColor: Color = isDarkAccent
            ? Color.white.opacity(0.10)
            : color.opacity(0.35)

        return HStack(spacing: 4) {
            Image(nsImage: logo)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: 11, height: 11)
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(.white)
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(fillGradient))
        .overlay(Capsule(style: .continuous).strokeBorder(borderGradient, lineWidth: 0.6))
        .shadow(color: shadowColor, radius: 1.5, y: 0.5)
    }
}

/// Brand logos for each provider. Paths are the official SVG symbols from the
/// Anthropic / OpenAI brand marks (public Wikimedia Commons versions), re-colored
/// to solid white so they read cleanly against the accent pill. macOS 14+ parses
/// SVG natively via `NSImage(data:)`, so no extra renderer is needed.
private enum ProviderLogo {
    static let claude: NSImage = makeImage(svg: claudeSVG)
    static let codex: NSImage = makeImage(svg: openAISVG)

    private static func makeImage(svg: String) -> NSImage {
        guard let data = svg.data(using: .utf8), let img = NSImage(data: data) else {
            return NSImage()
        }
        img.isTemplate = false
        return img
    }

    // Claude symbol: the Anthropic "starburst" mark — 8 asymmetric pointed rays
    // radiating out from center. Source: Wikimedia Commons "Claude_AI_symbol.svg".
    private static let claudeSVG = #"""
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 1200">
    <path fill="#ffffff" d="M 233.959793 800.214905 L 468.644287 668.536987 L 472.590637 657.100647 L 468.644287 650.738403 L 457.208069 650.738403 L 417.986633 648.322144 L 283.892639 644.69812 L 167.597321 639.865845 L 54.926208 633.825623 L 26.577238 627.785339 L 3.3e-05 592.751709 L 2.73832 575.27533 L 26.577238 559.248352 L 60.724873 562.228149 L 136.187973 567.382629 L 249.422867 575.194763 L 331.570496 580.026978 L 453.261841 592.671082 L 472.590637 592.671082 L 475.328857 584.859009 L 468.724915 580.026978 L 463.570557 575.194763 L 346.389313 495.785217 L 219.543671 411.865906 L 153.100723 363.543762 L 117.181267 339.060425 L 99.060455 316.107361 L 91.248367 266.01355 L 123.865784 230.093994 L 167.677887 233.073853 L 178.872513 236.053772 L 223.248367 270.201477 L 318.040283 343.570496 L 441.825592 434.738342 L 459.946411 449.798706 L 467.194672 444.64447 L 468.080597 441.020203 L 459.946411 427.409485 L 392.617493 305.718323 L 320.778564 181.932983 L 288.80542 130.630859 L 280.348999 99.865845 C 277.369171 87.221436 275.194641 76.590698 275.194641 63.624268 L 312.322174 13.20813 L 332.8591 6.604126 L 382.389313 13.20813 L 403.248352 31.328979 L 434.013519 101.71814 L 483.865753 212.537048 L 561.181274 363.221497 L 583.812134 407.919434 L 595.892639 449.315491 L 600.40271 461.959839 L 608.214783 461.959839 L 608.214783 454.711609 L 614.577271 369.825623 L 626.335632 265.61084 L 637.771851 131.516846 L 641.718201 93.745117 L 660.402832 48.483276 L 697.530334 24.000122 L 726.52356 37.852417 L 750.362549 72 L 747.060486 94.067139 L 732.886047 186.201416 L 705.100708 330.52356 L 686.979919 427.167847 L 697.530334 427.167847 L 709.61084 415.087341 L 758.496704 350.174561 L 840.644348 247.490051 L 876.885925 206.738342 L 919.167847 161.71814 L 946.308838 140.29541 L 997.61084 140.29541 L 1035.38269 196.429626 L 1018.469849 254.416199 L 965.637634 321.422852 L 921.825562 378.201538 L 859.006714 462.765259 L 819.785278 530.41626 L 823.409424 535.812073 L 832.75177 534.92627 L 974.657776 504.724915 L 1051.328979 490.872559 L 1142.818848 475.167786 L 1184.214844 494.496582 L 1188.724854 514.147644 L 1172.456421 554.335693 L 1074.604126 578.496765 L 959.838989 601.449829 L 788.939636 641.879272 L 786.845764 643.409485 L 789.261841 646.389343 L 866.255127 653.637634 L 899.194702 655.409424 L 979.812134 655.409424 L 1129.932861 666.604187 L 1169.154419 692.537109 L 1192.671265 724.268677 L 1188.724854 748.429688 L 1128.322144 779.194641 L 1046.818848 759.865845 L 856.590759 714.604126 L 791.355774 698.335754 L 782.335693 698.335754 L 782.335693 703.731567 L 836.69812 756.885986 L 936.322205 846.845581 L 1061.073975 962.81897 L 1067.436279 991.490112 L 1051.409424 1014.120911 L 1034.496704 1011.704712 L 924.885986 929.234924 L 882.604126 892.107544 L 786.845764 811.48999 L 780.483276 811.48999 L 780.483276 819.946289 L 802.550415 852.241699 L 919.087341 1027.409424 L 925.127625 1081.127686 L 916.671204 1098.604126 L 886.469849 1109.154419 L 853.288696 1103.114136 L 785.073914 1007.355835 L 714.684631 899.516785 L 657.906067 802.872498 L 650.979858 806.81897 L 617.476624 1167.704834 L 601.771851 1186.147705 L 565.530212 1200 L 535.328857 1177.046997 L 519.302124 1139.919556 L 535.328857 1066.550537 L 554.657776 970.792053 L 570.362488 894.68457 L 584.536926 800.134277 L 592.993347 768.724976 L 592.429626 766.630859 L 585.503479 767.516968 L 514.22821 865.369263 L 405.825531 1011.865906 L 320.053711 1103.677979 L 299.516815 1111.812256 L 263.919525 1093.369263 L 267.221497 1060.429688 L 287.114136 1031.114136 L 405.825531 880.107361 L 477.422913 786.52356 L 523.651062 732.483276 L 523.328918 724.671265 L 520.590698 724.671265 L 205.288605 929.395935 L 149.154434 936.644409 L 124.993355 914.01355 L 127.973183 876.885986 L 139.409409 864.80542 L 234.201385 799.570435 L 233.879227 799.8927 Z"/>
    </svg>
    """#

    // OpenAI 2025 "knot" mark only — the full SVG file also contains the word
    // "OpenAI" rendered as separate paths; we want just the symbol. Coordinates
    // cover roughly (1…322, 1…319), so viewBox "0 0 323 320" frames it with
    // negligible padding. Source: Wikimedia Commons "OpenAI_logo_2025.svg".
    private static let openAISVG = #"""
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 323 320">
    <path fill="#ffffff" d="M123.2,118.3V85c0-2.2,0.6-3.8,2.9-5.1L187.9,44c8.3-4.8,18.9-7,29.2-7c39.1,0,63.8,30.1,63.8,62.5c0,2.6,0,6.1-0.6,9l-64.7-37.8c-3.2-1.9-6.7-2.2-10.6,0L123.2,118.3z M266.1,236.6v-74c0-4.2-1.6-7-5.4-9.3l-82-47.7l28.8-16.7c1.6-1,4.2-1,5.8,0l62.2,35.9c17.6,10.3,29.8,32.7,29.8,54.1C305.2,204.2,289.8,227.6,266.1,236.6z M106.2,172.8l-28.5-17c-2.2-1.3-2.9-2.9-2.9-5.1V79.3c0-34.9,26.6-61.2,62.8-61.2c14.1,0,27.6,4.8,38.4,13.5L111.7,69c-3.8,2.2-5.4,5.1-5.4,9.3V172.8z M162,204.9l-38.8-21.8v-46.1l38.8-21.8l38.4,21.8v46.1L162,204.9z M186,301.9c-14.1,0-27.6-4.8-38.4-13.5L212,251c3.8-2.2,5.4-5.1,5.4-9.3v-94.5l28.8,17c2.2,1.3,2.9,2.9,2.9,5.1v71.5C249.1,275.7,222.2,301.9,186,301.9z M110.4,231.1l-62.2-35.9c-17.6-10.3-29.8-32.7-29.8-54.1c0-25.6,15.7-48.7,39.4-57.7v74.3c0,4.2,1.6,7,5.4,9.3l81.7,47.4l-28.8,16.7C114.6,232.1,112,232.1,110.4,231.1z M106.5,283c-36.8,0-63.8-27.6-63.8-61.8c0-3.2,0.3-6.4,0.6-9.3l64.4,37.2c3.8,2.2,7,2.2,10.9,0l81.7-47.4V235c0,2.2-0.6,3.8-2.9,5.1L135.7,276C127.4,280.8,116.8,283,106.5,283z M186,319.2c38.4,0,70.5-27.6,77.5-64.1c35.9-9,59-42.3,59-76.3c0-22.4-9.6-43.9-27.2-59.6c1.6-6.7,2.9-13.8,2.9-20.5c0-45.2-36.8-79.1-79.1-79.1c-8.7,0-17.3,1.6-25.6,4.5C179,9.7,159.4,0.8,137.6,0.8c-38.4,0-70.5,27.6-77.5,64.1c-35.9,9-59,42.3-59,76.3c0,22.4,9.6,43.9,27.2,59.6c-1.6,6.7-2.9,13.8-2.9,20.5c0,45.2,36.8,79.1,79.1,79.1c8.7,0,17.3,1.6,25.6,4.5C144.7,310.3,164.2,319.2,186,319.2z"/>
    </svg>
    """#
}
