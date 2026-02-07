import SwiftUI

enum Theme {
    // Backgrounds — warm, Claude-inspired dark mode
    static let background = Color(hex: 0x262624)
    static let surface = Color(hex: 0x31302E)
    static let surfaceHover = Color(hex: 0x393836)
    static let border = Color(hex: 0x44433F)
    static let borderLight = Color(hex: 0x54534E)

    // Text
    static let textPrimary = Color(hex: 0xEAE7E2)
    static let textSecondary = Color(hex: 0xA5A09A)
    static let textMuted = Color(hex: 0x7A756F)

    // Model colors
    static let opus = Color(hex: 0xA855F7)
    static let sonnet = Color(hex: 0x3B82F6)
    static let haiku = Color(hex: 0x14B8A6)

    // Status
    static let active = Color(hex: 0x22C55E)
    static let inactive = Color(hex: 0x666666)
    static let error = Color(hex: 0xEF4444)
    static let warning = Color(hex: 0xF59E0B)

    // Fonts
    static let monoBody = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)
    static let monoLarge = Font.system(.title3, design: .monospaced)
    static let monoHeading = Font.system(.title2, design: .monospaced).weight(.semibold)

    static func modelColor(_ model: ClaudeModel) -> Color {
        switch model {
        case .opus: opus
        case .sonnet: sonnet
        case .haiku: haiku
        }
    }

    // Spacing
    static let paddingSmall: CGFloat = 6
    static let paddingMedium: CGFloat = 12
    static let paddingLarge: CGFloat = 20
    static let cornerRadius: CGFloat = 8
    static let cornerRadiusSmall: CGFloat = 4
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
