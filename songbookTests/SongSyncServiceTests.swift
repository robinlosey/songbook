//
//  SongSyncServiceTests.swift
//  songbookTests
//
//  integration tests for songsyncservice with mocked components
//

import Testing
import Foundation
@testable import songbook

@Suite("SongSyncService Tests")
@MainActor
struct SongSyncServiceTests {

    let dataManager: DataManager

    init() {
        dataManager = DataManager.inMemory()

        // reset userdefaults keys used by sync
        UserDefaults.standard.removeObject(forKey: SyncKeys.storedCSVVersion)
        UserDefaults.standard.removeObject(forKey: SyncKeys.buildInProgress)
        UserDefaults.standard.removeObject(forKey: SyncKeys.lastSyncStatus)
        UserDefaults.standard.removeObject(forKey: SyncKeys.currentDB)
    }

    @Test("sync status can be recorded and retrieved")
    func syncStatusRecording() async {
        // manually record a status
        let status = SyncStatus(result: .success, fromVersion: 1, toVersion: 2)
        if let encoded = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(encoded, forKey: SyncKeys.lastSyncStatus)
        }

        let retrieved = SongSyncService.lastSyncStatus()
        #expect(retrieved != nil)
        #expect(retrieved?.result == .success)
        #expect(retrieved?.fromVersion == 1)
        #expect(retrieved?.toVersion == 2)
    }

    @Test("build in progress flag toggles correctly")
    func buildInProgressFlag() {
        // initially false
        #expect(UserDefaults.standard.bool(forKey: SyncKeys.buildInProgress) == false)

        // set to true
        UserDefaults.standard.set(true, forKey: SyncKeys.buildInProgress)
        #expect(UserDefaults.standard.bool(forKey: SyncKeys.buildInProgress) == true)

        // set to false
        UserDefaults.standard.set(false, forKey: SyncKeys.buildInProgress)
        #expect(UserDefaults.standard.bool(forKey: SyncKeys.buildInProgress) == false)
    }

    @Test("current db toggles between A and B")
    func currentDBToggle() {
        // defaults to A
        #expect(dataManager.currentStore == "A")

        // switch should flip
        dataManager.switchToInactiveStore()
        #expect(dataManager.currentStore == "B")

        dataManager.switchToInactiveStore()
        #expect(dataManager.currentStore == "A")
    }

    @Test("all sync states can be created and compared")
    func syncStateValues() {
        // test all sync states can be created
        let states: [SyncState] = [
            .idle,
            .checking,
            .downloading,
            .parsing,
            .building,
            .verifying,
            .complete,
            .failed("Test error")
        ]

        #expect(states.count == 8)

        // test equatable
        #expect(SyncState.idle == SyncState.idle)
        #expect(SyncState.idle != SyncState.checking)
        #expect(SyncState.failed("error") == SyncState.failed("error"))
        #expect(SyncState.failed("error1") != SyncState.failed("error2"))
    }

    @Test("sync errors have descriptions")
    func syncErrorDescriptions() {
        let errors: [SyncError] = [
            .networkUnavailable,
            .csvDownloadFailed(underlying: NSError(domain: "test", code: 1)),
            .csvParseFailed(line: 5, reason: "bad format"),
            .databaseError(underlying: NSError(domain: "test", code: 2)),
            .resourceDownloadFailed(filename: "test.pdf")
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription!.isEmpty == false)
        }
    }
}
