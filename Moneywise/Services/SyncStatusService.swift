//
//  SyncStatusService.swift
//  Moneywise
//
//  CloudKit sync status monitoring and user feedback
//

import Foundation
import CloudKit
import Observation
import SwiftUI

/// Sync state enum representing the current CloudKit sync status
enum SyncState: Equatable {
    case unknown
    case idle
    case syncing
    case success(message: String? = nil)
    case error(message: String)
    case disabled // User has disabled iCloud sync

    var displayText: String {
        switch self {
        case .unknown:
            return "Sync status unknown"
        case .idle:
            return "Synced"
        case .syncing:
            return "Syncing..."
        case .success(let message):
            return message ?? "Synced"
        case .error(let message):
            return message
        case .disabled:
            return "Sync disabled"
        }
    }

    var iconName: String {
        switch self {
        case .unknown:
            return "icloud.slash"
        case .idle:
            return "icloud.fill"
        case .syncing:
            return "icloud.and.arrow.up"
        case .success:
            return "checkmark.icloud.fill"
        case .error:
            return "exclamationmark.icloud.fill"
        case .disabled:
            return "icloud.slash.fill"
        }
    }

    var shouldShowIndicator: Bool {
        switch self {
        case .syncing, .error, .disabled:
            return true
        default:
            return false
        }
    }
}

/// Observable class that monitors CloudKit sync status
@Observable final class SyncStatusMonitor {
    private(set) var syncState: SyncState = .unknown
    private(set) var lastSyncDate: Date?
    private var successTimer: Timer?

    init() {
        checkInitialSyncStatus()
    }

    // MARK: - Public Methods

    /// Update sync state to syncing
    func setSyncing() {
        updateState(.syncing)
    }

    /// Update sync state to success with optional message
    func setSuccess(message: String? = nil) {
        updateState(.success(message: message))
        lastSyncDate = Date()

        // Auto-transition to idle after 3 seconds
        successTimer?.invalidate()
        successTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.updateState(.idle)
        }
    }

    /// Update sync state to error with message
    func setError(message: String) {
        updateState(.error(message: message))
    }

    /// Update sync state to idle
    func setIdle() {
        updateState(.idle)
    }

    /// Update sync state to disabled
    func setDisabled() {
        updateState(.disabled)
    }

    /// Check if currently syncing
    var isSyncing: Bool {
        if case .syncing = syncState {
            return true
        }
        return false
    }

    /// Check if there's an error
    var hasError: Bool {
        if case .error = syncState {
            return true
        }
        return false
    }

    // MARK: - Private Methods

    private func updateState(_ newState: SyncState) {
        Task { @MainActor in
            syncState = newState
        }
    }

    private func checkInitialSyncStatus() {
        // Check if user is signed into iCloud
        CKContainer.default().accountStatus { [weak self] status, error in
            Task { @MainActor in
                switch status {
                case .available:
                    self?.syncState = .idle
                case .noAccount:
                    self?.syncState = .error(message: "Not signed into iCloud")
                case .restricted:
                    self?.syncState = .error(message: "iCloud access restricted")
                case .couldNotDetermine:
                    self?.syncState = .unknown
                case .temporarilyUnavailable:
                    self?.syncState = .error(message: "iCloud temporarily unavailable")
                @unknown default:
                    self?.syncState = .unknown
                }

                if let error {
                    self?.syncState = .error(message: error.localizedDescription)
                }
            }
        }
    }

    /// Manually trigger a sync status check
    func refreshAccountStatus() {
        checkInitialSyncStatus()
    }
}

// MARK: - View Modifier for CloudKit Sync Monitoring

extension View {
    /// Attaches CloudKit sync monitoring to the view
    func cloudKitSyncMonitor(_ monitor: SyncStatusMonitor) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            monitor.setSuccess(message: "Synced with iCloud")
        }
    }
}

// MARK: - Sync Status Indicator View

struct SyncStatusIndicator: View {
    @Environment(\.syncStatus) private var syncStatus

    var body: some View {
        if syncStatus.syncState.shouldShowIndicator || syncStatus.hasError {
            HStack(spacing: 4) {
                Image(systemName: syncStatus.syncState.iconName)
                    .font(.caption)
                    .foregroundColor(statusColor)
                Text(syncStatus.syncState.displayText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var statusColor: Color {
        switch syncStatus.syncState {
        case .syncing:
            return .blue
        case .error:
            return .red
        case .disabled:
            return .gray
        default:
            return .green
        }
    }
}

// MARK: - CloudKit Error Handler

enum CloudSyncError: LocalizedError {
    case notLoggedIn
    case networkError(Error)
    case quotaExceeded
    case accountRestricted
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Please sign in to iCloud in Settings to enable sync"
        case .networkError:
            return "Network error. Please check your connection"
        case .quotaExceeded:
            return "iCloud storage full. Please manage your storage"
        case .accountRestricted:
            return "iCloud account is restricted"
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    static func from(_ error: Error) -> CloudSyncError {
        let nsError = error as NSError

        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated, .noAccount:
                return .notLoggedIn
            case .networkFailure, .networkUnavailable:
                return .networkError(error)
            case .quotaExceeded:
                return .quotaExceeded
            case .accountRestricted:
                return .accountRestricted
            default:
                return .unknown(error)
            }
        }

        return .unknown(error)
    }
}
