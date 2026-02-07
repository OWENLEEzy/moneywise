import SwiftUI

@Observable
class AppTheme {
    enum ThemeOption: String, CaseIterable, Identifiable, Codable {
        case mint = "Mint"
        case ocean = "Ocean"
        case sunset = "Sunset"
        case forest = "Forest"
        case dark = "Dark"

        var id: String { rawValue }

        // Localized display names
        var localizedName: LocalizedStringResource {
            switch self {
            case .mint: return "Mint (薄荷)"
            case .ocean: return "Ocean (海洋)"
            case .sunset: return "Sunset (日落)"
            case .forest: return "Forest (森林)"
            case .dark: return "Dark (深色)"
            }
        }

        // Primary color - used for buttons, accents, hero cards
        var primaryColor: Color {
            switch self {
            case .mint:
                return Color(red: 0.2, green: 0.8, blue: 0.6)
            case .ocean:
                return Color(red: 0.0, green: 0.47, blue: 0.71)
            case .sunset:
                return Color(red: 1.0, green: 0.42, blue: 0.42)
            case .forest:
                return Color(red: 0.18, green: 0.42, blue: 0.31)
            case .dark:
                return Color(red: 0.3, green: 0.3, blue: 0.3)
            }
        }

        // Secondary color - used for gradients, secondary elements
        var secondaryColor: Color {
            switch self {
            case .mint:
                return Color(red: 0.1, green: 0.6, blue: 0.5)
            case .ocean:
                return Color(red: 0.0, green: 0.24, blue: 0.54)
            case .sunset:
                return Color(red: 0.93, green: 0.35, blue: 0.35)
            case .forest:
                return Color(red: 0.11, green: 0.27, blue: 0.2)
            case .dark:
                return Color(red: 0.2, green: 0.2, blue: 0.2)
            }
        }

        // Background color - main app background
        var backgroundColor: Color {
            switch self {
            case .mint, .ocean, .sunset, .forest:
                return Color(red: 0.97, green: 0.97, blue: 0.98)
            case .dark:
                return Color(red: 0.1, green: 0.1, blue: 0.1)
            }
        }

        // Card background color
        var cardColor: Color {
            switch self {
            case .mint, .ocean, .sunset, .forest:
                return Color.white
            case .dark:
                return Color(red: 0.15, green: 0.15, blue: 0.15)
            }
        }

        // Primary text color
        var textColor: Color {
            switch self {
            case .mint, .ocean, .sunset, .forest:
                return Color(red: 0.2, green: 0.2, blue: 0.25)
            case .dark:
                return Color(red: 0.95, green: 0.95, blue: 0.95)
            }
        }

        // Secondary text color (captions, subtitles)
        var secondaryTextColor: Color {
            switch self {
            case .mint, .ocean, .sunset, .forest:
                return Color(red: 0.5, green: 0.5, blue: 0.55)
            case .dark:
                return Color(red: 0.7, green: 0.7, blue: 0.7)
            }
        }

        // Status colors
        var successColor: Color { Color(red: 0.2, green: 0.8, blue: 0.4) }
        var warningColor: Color { Color(red: 1.0, green: 0.6, blue: 0.0) }
        var errorColor: Color { Color(red: 1.0, green: 0.3, blue: 0.3) }

        // Gradient for hero cards
        var heroGradient: LinearGradient {
            LinearGradient(
                colors: [primaryColor, secondaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // Current theme selection
    var currentTheme: ThemeOption {
        didSet {
            saveThemePreference()
        }
    }

    // UserDefaults key
    private let themeKey = "appTheme"

    init() {
        // Load saved theme or default to mint
        if let savedThemeRaw = UserDefaults.standard.string(forKey: themeKey),
           let savedTheme = ThemeOption(rawValue: savedThemeRaw) {
            self.currentTheme = savedTheme
        } else {
            self.currentTheme = .mint
        }
    }

    // MARK: - Persistence

    private func saveThemePreference() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
    }

    // MARK: - Convenience Accessors

    var primary: Color { currentTheme.primaryColor }
    var secondary: Color { currentTheme.secondaryColor }
    var background: Color { currentTheme.backgroundColor }
    var card: Color { currentTheme.cardColor }
    var text: Color { currentTheme.textColor }
    var secondaryText: Color { currentTheme.secondaryTextColor }
    var success: Color { currentTheme.successColor }
    var warning: Color { currentTheme.warningColor }
    var error: Color { currentTheme.errorColor }
    var gradient: LinearGradient { currentTheme.heroGradient }
}

// MARK: - Environment Key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme()
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
