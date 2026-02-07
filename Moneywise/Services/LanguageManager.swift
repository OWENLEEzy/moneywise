//
//  LanguageManager.swift
//  Moneywise
//
//  Created by Owen Lee on 2025-02-07.
//  Description: Localization and language management service
//

import SwiftUI
import Combine

/// # Language
///
/// Enum representing supported languages in the app.
///
/// ## Available Languages
/// - `.en`: English
/// - `.zh`: Simplified Chinese (zh-Hans)
///
/// ## Usage
/// ```swift
/// let current = LanguageManager.shared.selectedLanguage
/// print(current.displayName) // "English" or "中文"
/// ```
enum Language: String, CaseIterable {
    case en = "en"
    case zh = "zh-Hans"

    /// Display name for the language in its native script
    var displayName: String {
        switch self {
        case .en: return "English"
        case .zh: return "中文"
        }
    }
}

/// # LanguageManager
///
/// ## Overview
/// Singleton service that manages app localization and language switching.
/// Handles loading of language bundles, persisting user language preference,
/// and providing localized strings throughout the app.
///
/// ## Usage
/// ```swift
/// // Get localized string
/// let welcome = LanguageManager.shared.localizedString("welcome_key")
///
/// // Using String extension (more convenient)
/// let goodbye = "goodbye_key".localized
///
/// // Change language
/// LanguageManager.shared.selectedLanguageCode = "zh"
///
/// // Get current locale for number/date formatting
/// let locale = LanguageManager.shared.locale
/// ```
///
/// ## Localization Setup
/// 1. Add .lproj directories for each language (e.g., en.lproj, zh-Hans.lproj)
/// 2. Add Localizable.strings files to each directory
/// 3. Use `String.localized` extension for UI strings
///
/// ## Thread Safety
/// This class is an `ObservableObject` with `@Published` properties.
/// Language changes should be made from the main thread for SwiftUI updates.
///
/// ## Dependencies
/// - Foundation: Bundle and UserDefaults for language storage
/// - SwiftUI: @Published properties for reactivity
/// - Combine: ObservableObject conformance
///
/// ## Persistence
/// Language preference is stored in UserDefaults with key "selectedLanguage".
/// Defaults to "en" (English) if not set.

/// Service for managing app language and localization
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @AppStorage("selectedLanguage") var selectedLanguageCode: String = "en" {
        didSet {
            updateBundle()
        }
    }

    @Published var bundle: Bundle?

    /// Initializes the manager and loads the initial language bundle
    ///
    /// Called once when the singleton is first accessed. Loads the appropriate
    /// language bundle based on the stored preference (or English as default).
    init() {
        updateBundle()
    }

    /// Updates the language bundle based on current selection
    ///
    /// Loads the .lproj directory for the selected language code.
    /// Falls back to English if the selected language bundle is not found.
    private func updateBundle() {
        if let path = Bundle.main.path(forResource: selectedLanguageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            // Fallback to main bundle or English
            if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let bundle = Bundle(path: path) {
                self.bundle = bundle
            } else {
                self.bundle = Bundle.main
            }
        }
    }

    /// Returns a localized string for the given key
    ///
    /// Searches the current language bundle for the localized string.
    /// Returns the key itself if no translation is found (fallback behavior).
    ///
    /// - Parameter key: Localizable.strings key
    /// - Returns: Localized string, or the key if not found
    /// - Note: Prefer using the `String.localized` extension for cleaner syntax
    func localizedString(_ key: String) -> String {
        return bundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
    }

    /// Returns a Locale appropriate for the current language
    ///
    /// Used for date and number formatting to match the selected language.
    ///
    /// - Returns: Locale object (zh_CN for Chinese, en_US for English)
    var locale: Locale {
        switch selectedLanguageCode {
        case "zh-Hans": return Locale(identifier: "zh_CN")
        default: return Locale(identifier: "en_US")
        }
    }
}

// Helper extension for easier usage in Views
extension String {
    /// Returns the localized version of this string
    ///
    /// Uses the shared LanguageManager to look up the translation.
    /// The string itself is used as the key in Localizable.strings.
    ///
    /// ## Usage
    /// ```swift
    /// Text("welcome_message".localized)
    /// ```
    var localized: String {
        LanguageManager.shared.localizedString(self)
    }
}
