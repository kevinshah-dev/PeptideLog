import SwiftUI
import UIKit

enum AppTheme {
    static let accent = Color(hex: 0x29F4B5)
    static let background = Color.adaptive(light: 0xF4F8F6, dark: 0x0D0D0D)
    static let elevated = Color.adaptive(light: 0xFFFFFF, dark: 0x171717)
    static let elevatedStrong = Color.adaptive(light: 0xEAF1EE, dark: 0x202020)
    static let textPrimary = Color.adaptive(light: 0x101414, dark: 0xF6F7F7)
    static let textSecondary = Color.adaptive(light: 0x58625E, dark: 0xA9B0AD)
    static let divider = Color.adaptive(light: 0x101414, dark: 0xFFFFFF, lightOpacity: 0.10, darkOpacity: 0.08)
    static let warning = Color.adaptive(light: 0xB7790C, dark: 0xF8C14A)
    static let danger = Color.adaptive(light: 0xC73535, dark: 0xFF6B6B)
    static let blue = Color.adaptive(light: 0x256FD8, dark: 0x69A7FF)
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case dark = "Dark"
    case light = "Light"
    case system = "System"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

extension Color {
    init(hex: Int, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    static func adaptive(
        light: Int,
        dark: Int,
        lightOpacity: Double = 1,
        darkOpacity: Double = 1
    ) -> Color {
        Color(
            UIColor { traits in
                let isDark = traits.userInterfaceStyle == .dark
                return UIColor(
                    hex: isDark ? dark : light,
                    opacity: isDark ? darkOpacity : lightOpacity
                )
            }
        )
    }
}

extension View {
    func protocolsScreen() -> some View {
        background(AppTheme.background.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.textPrimary)
    }
}

private extension UIColor {
    convenience init(hex: Int, opacity: Double = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: CGFloat(opacity))
    }
}
