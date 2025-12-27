//
//  SyncManager.swift
//  songbook
//
//  Observable wrapper for sync operations. Provides:
//  - Observable state for automatic UI updates
//  - NotificationCenter trigger for sync from anywhere
//

import Foundation
import os.log

extension Notification.Name {
    static let syncRequested = Notification.Name("syncRequested")
}

@Observable
final class SyncManager: @unchecked Sendable {
    static let shared = SyncManager()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SyncManager")
    
    // observable state - views subscribe automatically
    private(set) var state: SyncState = .idle
    private(set) var lastSyncStatus: SyncStatus?
    
    private let syncService: SongSyncService
    private var isSyncing = false
    
    init(dataManager: DataManager = .shared) {
        self.syncService = SongSyncService(dataManager: dataManager)
        self.lastSyncStatus = SongSyncService.lastSyncStatus()
        
        // listen for sync trigger from anywhere
        NotificationCenter.default.addObserver(
            forName: .syncRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.sync() }
        }
    }
    
    /// triggers a sync - can also be called directly
    func sync() async {
        guard !isSyncing else {
            Self.logger.debug("Sync already in progress, ignoring request")
            return
        }
        
        isSyncing = true
        Self.logger.info("Starting sync")
        
        // forward state updates from service
        await observeAndSync()
        
        isSyncing = false
        lastSyncStatus = SongSyncService.lastSyncStatus()
    }
    
    private func observeAndSync() async {
        // observe state updates via stream (push-based, more efficient than polling)
        let observeTask = Task { @MainActor in
            for await serviceState in await syncService.stateStream {
                self.state = serviceState
            }
        }
        
        await syncService.sync()
        observeTask.cancel()
        
        // get final state from service
        state = await syncService.state
    }
    
    /// convenience for posting sync request from anywhere
    static func requestSync() {
        NotificationCenter.default.post(name: .syncRequested, object: nil)
    }
    
    /// current CSV version
    var currentVersion: Int {
        UserDefaults.standard.integer(forKey: SyncKeys.storedCSVVersion)
    }
}

