//
//  SongSyncService.swift
//  songbook
//
//  Actor orchestrating the full sync flow with A/B database swap.
//

import Foundation
import os.log

actor SongSyncService {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SongSyncService")

    private let dataManager: DataManager
    private let networkMonitor: NetworkMonitor
    private let downloader: ResourceDownloader

    // observable state for UI
    @MainActor var state: SyncState = .idle

    // push-based state stream for efficient observation
    let stateStream: AsyncStream<SyncState>
    private let stateContinuation: AsyncStream<SyncState>.Continuation

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    // production initializer using singletons
    init(dataManager: DataManager = .shared) {
        self.dataManager = dataManager
        self.networkMonitor = NetworkMonitor.shared
        self.downloader = ResourceDownloader.shared

        // create async stream for state updates
        (stateStream, stateContinuation) = AsyncStream.makeStream(of: SyncState.self)
    }

    // testing initializer with dependency injection
    init(dataManager: DataManager, networkMonitor: NetworkMonitor, downloader: ResourceDownloader) {
        self.dataManager = dataManager
        self.networkMonitor = networkMonitor
        self.downloader = downloader

        (stateStream, stateContinuation) = AsyncStream.makeStream(of: SyncState.self)
    }

    // MARK: - Main Sync Flow

    func sync() async {
        await setState(.checking)

        // recover from crashed build if needed
        await recoverFromCrashedBuild()

        // get versions
        let storedVersion = UserDefaults.standard.integer(forKey: SyncKeys.storedCSVVersion)
        let bundledVersion = DataManager.bundledCSVVersion
        let onlineVersion = await fetchOnlineVersion() ?? 0

        Self.logger.info("Versions - stored: \(storedVersion), bundled: \(bundledVersion), online: \(onlineVersion)")

        let targetVersion = max(bundledVersion, onlineVersion)

        // check if database is empty (force sync if so, even if versions match)
        let databaseIsEmpty = dataManager.fetchAllSongs().isEmpty
        if databaseIsEmpty {
            Self.logger.warning("Database is empty - forcing sync")
        }

        // check if update needed
        guard targetVersion > storedVersion || databaseIsEmpty else {
            Self.logger.info("No update needed")
            await recordStatus(.noUpdateNeeded, fromVersion: storedVersion)
            await verifyIntegrity()
            await setState(.complete)
            return
        }

        let useOnline = onlineVersion >= bundledVersion && networkMonitor.isConnected
        Self.logger.info("Update needed: \(storedVersion) -> \(targetVersion), source: \(useOnline ? "online" : "bundled")")

        // mark build in progress (crash recovery flag)
        UserDefaults.standard.set(true, forKey: SyncKeys.buildInProgress)

        // fetch favorites from current DB
        let favorites = dataManager.fetchFavoriteFilenames()
        Self.logger.info("Preserved \(favorites.count) favorites")

        // fetch CSV
        await setState(.downloading)
        let csvContent: String
        do {
            csvContent = try await fetchCSV(preferOnline: useOnline)
        } catch {
            Self.logger.error("CSV fetch failed: \(error)")
            await recordStatus(.failed, fromVersion: storedVersion, error: error)
            UserDefaults.standard.set(false, forKey: SyncKeys.buildInProgress)
            await setState(.failed(error.localizedDescription))
            return
        }

        // parse CSV
        await setState(.parsing)
        let songs: [SongDTO]
        do {
            songs = try CSVParser.parse(csvContent)
        } catch {
            Self.logger.error("CSV parse failed: \(error)")
            await recordStatus(.failed, fromVersion: storedVersion, error: error)
            UserDefaults.standard.set(false, forKey: SyncKeys.buildInProgress)
            await setState(.failed(error.localizedDescription))
            return
        }

        // build new DB in inactive store
        await setState(.building)
        do {
            let inactiveContainer = dataManager.createInactiveContainer()
            try dataManager.flushDatabase(inactiveContainer)
            try await dataManager.populate(inactiveContainer, with: songs, favorites: favorites)
        } catch {
            Self.logger.error("Database build failed: \(error)")
            await recordStatus(.failed, fromVersion: storedVersion, error: error)
            UserDefaults.standard.set(false, forKey: SyncKeys.buildInProgress)
            await setState(.failed(error.localizedDescription))
            return
        }

        // success - switch stores (on main thread for thread safety)
        await MainActor.run {
            dataManager.switchToInactiveStore()
        }
        UserDefaults.standard.set(targetVersion, forKey: SyncKeys.storedCSVVersion)
        UserDefaults.standard.set(false, forKey: SyncKeys.buildInProgress)

        Self.logger.info("Database update complete: \(storedVersion) -> \(targetVersion)")
        await recordStatus(.success, fromVersion: storedVersion, toVersion: targetVersion)

        // verify integrity and queue downloads
        await verifyIntegrity()

        await setState(.complete)
    }

    // MARK: - Crash Recovery

    private func recoverFromCrashedBuild() async {
        guard UserDefaults.standard.bool(forKey: SyncKeys.buildInProgress) else { return }

        Self.logger.warning("Detected crashed build - cleaning up inactive store")

        // flush the inactive store to clean up partial data
        let inactiveContainer = dataManager.createInactiveContainer()
        try? dataManager.flushDatabase(inactiveContainer)

        UserDefaults.standard.set(false, forKey: SyncKeys.buildInProgress)
        Self.logger.info("Crash recovery complete")
    }

    // MARK: - Integrity Verification

    func verifyIntegrity() async {
        await setState(.verifying)
        Self.logger.info("Verifying database integrity")

        let songs = dataManager.fetchAllSongs()
        var missingPDFs = 0
        var missingMP3s = 0

        // queue missing resources
        for song in songs {
            guard let filename = song.filename else { continue }

            if DataManager.getSongPDF(for: filename) == nil {
                await downloader.queueDownload(filename: filename, type: .pdf)
                missingPDFs += 1
            }

            if DataManager.getSongMP3(for: filename) == nil {
                await downloader.queueDownload(filename: filename, type: .mp3)
                missingMP3s += 1
            }
        }

        Self.logger.info("Missing resources: \(missingPDFs) PDFs, \(missingMP3s) MP3s")

        // phase 1: download PDFs (required for sync completion)
        if missingPDFs > 0 {
            await downloader.processPDFs()
        }

        // sync is complete once PDFs are done - MP3s are optional
        Self.logger.info("PDF downloads complete - sync finished")

        // phase 2: background MP3 downloads (non-blocking, network-aware)
        if missingMP3s > 0 {
            Task.detached { [downloader] in
                await downloader.processMP3s()
            }
        }
    }

    // MARK: - Network Operations

    private func fetchOnlineVersion() async -> Int? {
        guard networkMonitor.isConnected,
              let url = URL(string: dataManager.csvVersionURL) else {
            return nil
        }

        do {
            let (data, _) = try await session.data(from: url)
            let versionString = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return versionString.flatMap { Int($0) }
        } catch {
            Self.logger.error("Failed to fetch online version: \(error)")
            return nil
        }
    }

    private func fetchCSV(preferOnline: Bool) async throws -> String {
        // try online first if preferred
        if preferOnline, networkMonitor.isConnected {
            if let content = await downloadCSV() {
                return content
            }
            Self.logger.warning("Online CSV failed, falling back to bundled")
        }

        // fall back to bundled
        guard let bundlePath = Bundle.main.path(forResource: "songs", ofType: "csv"),
              let content = try? String(contentsOfFile: bundlePath, encoding: .utf8) else {
            throw SyncError.csvDownloadFailed(underlying: NSError(domain: "SongSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "No CSV source available"]))
        }

        Self.logger.info("Loaded CSV from bundle")
        return content
    }

    private func downloadCSV() async -> String? {
        guard let url = URL(string: dataManager.csvDownloadURL) else { return nil }

        do {
            let (data, _) = try await session.data(from: url)

            // save to app support for future reference
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let csvPath = appSupport.appendingPathComponent("songs.csv")
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            try? data.write(to: csvPath)

            return String(data: data, encoding: .utf8)
        } catch {
            Self.logger.error("CSV download failed: \(error)")
            return nil
        }
    }

    // MARK: - State Management

    private func setState(_ newState: SyncState) async {
        await MainActor.run { state = newState }
        stateContinuation.yield(newState)
        Self.logger.debug("State: \(String(describing: newState))")

        // finish stream on terminal states
        if case .complete = newState {
            stateContinuation.finish()
        } else if case .failed = newState {
            stateContinuation.finish()
        }
    }

    private func recordStatus(_ result: SyncStatus.Result, fromVersion: Int, toVersion: Int? = nil, error: Error? = nil) async {
        let status = SyncStatus(
            result: result,
            fromVersion: fromVersion,
            toVersion: toVersion,
            errorMessage: error?.localizedDescription
        )

        if let encoded = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(encoded, forKey: SyncKeys.lastSyncStatus)
        }

        // track last successful update separately
        if result == .success {
            UserDefaults.standard.set(Date(), forKey: SyncKeys.lastUpdatedTimestamp)
        }
    }

    // MARK: - Status Access

    static func lastSyncStatus() -> SyncStatus? {
        guard let data = UserDefaults.standard.data(forKey: SyncKeys.lastSyncStatus) else { return nil }
        return try? JSONDecoder().decode(SyncStatus.self, from: data)
    }
}
