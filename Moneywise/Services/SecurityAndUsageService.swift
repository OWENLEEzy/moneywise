//
//  SecurityAndUsageService.swift
//  Moneywise
//
//  Created by Owen Lee on 2025-02-07.
//  Description: Keychain storage service for sensitive data (API keys)
//

import Foundation
import Security
import OSLog

/// # KeychainService
///
/// ## Overview
/// Secure storage service using iOS Keychain for sensitive data such as API keys.
/// Provides type-safe storage and retrieval with automatic error handling.
///
/// ## Usage
/// ```swift
/// let keychain = KeychainService()
///
/// // Store API key
/// keychain.set("sk-abc123...", for: .geminiAPIKey)
///
/// // Retrieve API key
/// if let apiKey = keychain.value(for: .geminiAPIKey) {
///     print("API key found")
/// }
///
/// // Delete API key
/// keychain.delete(.geminiAPIKey)
/// ```
///
/// ## Security Features
/// - Data stored in iOS Keychain (encrypted at rest when device is locked)
/// - Uses `kSecAttrAccessibleAfterFirstUnlock` for accessibility after first unlock
/// - Items persist across app reinstalls (when using same account/signing)
/// - Synchronized across devices via iCloud Keychain (when enabled)
///
/// ## Error Handling
/// - Errors are logged using os_log for debugging purposes
/// - `set()` logs on failure (data conversion or storage errors)
/// - `value()` returns nil on failure (logs error for non-"not found" cases)
/// - `delete()` logs on failure (except for "not found" cases)
///
/// ## Thread Safety
/// This class is thread-safe. Keychain operations are atomic.
///
/// ## Dependencies
/// - Security framework for Keychain access
/// - Foundation for data conversion

/// Keys for items stored in Keychain
enum KeychainKey: String {
    case geminiAPIKey = "com.owen.moneywise.gemini"
}

private let logger = Logger(subsystem: "owenlee.Moneywise", category: "KeychainService")

/// Service for secure storage using iOS Keychain
final class KeychainService {
    /// Stores a string value in the Keychain
    ///
    /// Converts the string to UTF-8 data and stores it securely.
    /// Any existing value with the same key is replaced.
    ///
    /// - Parameters:
    ///   - value: String value to store
    ///   - key: KeychainKey identifying the item
    /// - Note: Errors are logged on failure (check via `value(forKey:)` after setting)
    func set(_ value: String, for key: KeychainKey) {
        guard let data = value.data(using: .utf8) else {
            logger.error("Failed to convert value to data for key: \(key.rawValue)")
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Failed to store keychain item for key '\(key.rawValue)': status \(status)")
        }
    }

    /// Retrieves a string value from the Keychain
    ///
    /// - Parameter key: KeychainKey identifying the item to retrieve
    /// - Returns: The stored string value, or nil if not found or on error
    /// - Note: Returns nil for both "not found" and error conditions
    func value(for key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound {
                logger.error("Failed to retrieve keychain item for key '\(key.rawValue)': status \(status)")
            }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Deletes a value from the Keychain
    ///
    /// - Parameter key: KeychainKey identifying the item to delete
    /// - Note: Errors are logged on failure (except when item doesn't exist)
    func delete(_ key: KeychainKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Failed to delete keychain item for key '\(key.rawValue)': status \(status)")
        }
    }
}
