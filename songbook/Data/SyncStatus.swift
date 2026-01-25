//
//  SyncStatus.swift
//  songbook
//
//  Types for tracking sync state and history.
//

import Foundation

// persisted to UserDefaults after each sync attempt
struct SyncStatus: Codable, Sendable {
    enum Result: String, Codable, Sendable {
        case success
        case noUpdateNeeded
        case failed
    }
    
    let result: Result
    let timestamp: Date
    let fromVersion: Int
    let toVersion: Int?
    let errorMessage: String?
    
    init(result: Result, fromVersion: Int, toVersion: Int? = nil, errorMessage: String? = nil) {
        self.result = result
        self.timestamp = Date()
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.errorMessage = errorMessage
    }
}

// observable state for UI (not persisted)
enum SyncState: Equatable, Sendable {
    case idle
    case checking
    case downloading
    case parsing
    case building
    case verifying
    case complete
    case failed(String)
}

// centralized UserDefaults keys for sync state
enum SyncKeys {
    static let currentDB = "currentDB"                   // "A" or "B"
    static let buildInProgress = "buildInProgress"       // crash recovery flag
    static let lastSyncStatus = "lastSyncStatus"         // JSON-encoded SyncStatus
    static let storedCSVVersion = "storedCSVVersion"     // version of current DB
}

// notification posted after A/B database swap completes
extension Notification.Name {
    static let databaseDidSwitch = Notification.Name("databaseDidSwitch")
}

// error types for sync operations
enum SyncError: Error, LocalizedError {
    case networkUnavailable
    case csvDownloadFailed(underlying: Error)
    case csvParseFailed(line: Int, reason: String)
    case databaseError(underlying: Error)
    case resourceDownloadFailed(filename: String)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No network connection available"
        case .csvDownloadFailed(let error):
            return "Failed to download song list: \(error.localizedDescription)"
        case .csvParseFailed(let line, let reason):
            return "Failed to parse song list at line \(line): \(reason)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .resourceDownloadFailed(let filename):
            return "Failed to download resource: \(filename)"
        }
    }
}

