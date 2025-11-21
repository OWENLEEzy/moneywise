import SwiftUI
import Combine

enum Language: String, CaseIterable {
    case en = "en"
    case zh = "zh-Hans"
    
    var displayName: String {
        switch self {
        case .en: return "English"
        case .zh: return "中文"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("selectedLanguage") var selectedLanguageCode: String = "en" {
        didSet {
            updateBundle()
        }
    }
    
    @Published var bundle: Bundle?
    
    init() {
        updateBundle()
    }
    
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
    
    func localizedString(_ key: String) -> String {
        return bundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
    }
    
    var locale: Locale {
        switch selectedLanguageCode {
        case "zh-Hans": return Locale(identifier: "zh_CN")
        default: return Locale(identifier: "en_US")
        }
    }
}

// Helper extension for easier usage in Views
extension String {
    var localized: String {
        LanguageManager.shared.localizedString(self)
    }
}
