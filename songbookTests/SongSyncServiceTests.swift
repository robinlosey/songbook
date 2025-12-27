//
//  SongSyncServiceTests.swift
//  songbookTests
//
//  Integration tests for SongSyncService with mocked components.
//

import XCTest
@testable import songbook

final class SongSyncServiceTests: XCTestCase {
    
    var dataManager: DataManager!
    
    override func setUp() {
        super.setUp()
        dataManager = DataManager.inMemory()
        
        // reset UserDefaults keys used by sync
        UserDefaults.standard.removeObject(forKey: SyncKeys.storedCSVVersion)
        UserDefaults.standard.removeObject(forKey: SyncKeys.buildInProgress)
        UserDefaults.standard.removeObject(forKey: SyncKeys.lastSyncStatus)
        UserDefaults.standard.removeObject(forKey: SyncKeys.currentDB)
    }
    
    override func tearDown() {
        dataManager = nil
        super.tearDown()
    }
    
    func testSyncStatusRecording() async {
        // manually record a status
        let status = SyncStatus(result: .success, fromVersion: 1, toVersion: 2)
        if let encoded = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(encoded, forKey: SyncKeys.lastSyncStatus)
        }
        
        let retrieved = SongSyncService.lastSyncStatus()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.result, .success)
        XCTAssertEqual(retrieved?.fromVersion, 1)
        XCTAssertEqual(retrieved?.toVersion, 2)
    }
    
    func testBuildInProgressFlag() {
        // initially false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: SyncKeys.buildInProgress))
        
        // set to true
        UserDefaults.standard.set(true, forKey: SyncKeys.buildInProgress)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: SyncKeys.buildInProgress))
        
        // set to false
        UserDefaults.standard.set(false, forKey: SyncKeys.buildInProgress)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: SyncKeys.buildInProgress))
    }
    
    func testCurrentDBToggle() {
        // defaults to A
        XCTAssertEqual(dataManager.currentStore, "A")
        
        // switch should flip
        dataManager.switchToInactiveStore()
        XCTAssertEqual(dataManager.currentStore, "B")
        
        dataManager.switchToInactiveStore()
        XCTAssertEqual(dataManager.currentStore, "A")
    }
    
    func testSyncStateValues() {
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
        
        XCTAssertEqual(states.count, 8)
        
        // test equatable
        XCTAssertEqual(SyncState.idle, SyncState.idle)
        XCTAssertNotEqual(SyncState.idle, SyncState.checking)
        XCTAssertEqual(SyncState.failed("error"), SyncState.failed("error"))
        XCTAssertNotEqual(SyncState.failed("error1"), SyncState.failed("error2"))
    }
    
    func testSyncErrorDescriptions() {
        let errors: [SyncError] = [
            .networkUnavailable,
            .csvDownloadFailed(underlying: NSError(domain: "test", code: 1)),
            .csvParseFailed(line: 5, reason: "bad format"),
            .databaseError(underlying: NSError(domain: "test", code: 2)),
            .resourceDownloadFailed(filename: "test.pdf")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

