//
//  DownloadService.swift
//  songbook
//
//  Singleton service for user-triggered downloads and MP3 availability checks.
//  Separate from sync-related downloads for cleaner architecture.
//

import Foundation
import os.log

@Observable
@MainActor
final class DownloadService {
    static let shared = DownloadService()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DownloadService")

    private let downloader: ResourceDownloader
    private let networkMonitor: NetworkMonitor

    // cache for MP3 availability checks
    private var availabilityCache: [String: DataManager.MP3Availability] = [:]

    // track active downloads
    private(set) var activeDownloads: Set<String> = []

    private init() {
        self.networkMonitor = NetworkMonitor.shared
        self.downloader = ResourceDownloader.shared
    }

    // MARK: - MP3 Availability

    /// checks MP3 availability, using cache when possible
    func checkMP3Availability(for filename: String) async -> DataManager.MP3Availability {
        // check local first
        if let url = DataManager.getSongMP3(for: filename) {
            availabilityCache[filename] = .available(url)
            return .available(url)
        }

        // check cache
        if let cached = availabilityCache[filename] {
            return cached
        }

        // check server
        let exists = await downloader.checkMP3Exists(filename: filename)
        let availability: DataManager.MP3Availability = exists ? .downloadable : .notFound
        availabilityCache[filename] = availability

        Self.logger.debug("MP3 availability for \(filename): \(exists ? "downloadable" : "not found")")
        return availability
    }

    /// clears availability cache (call after successful download)
    func invalidateCache(for filename: String) {
        availabilityCache.removeValue(forKey: filename)
    }

    // MARK: - User-Triggered Downloads

    /// downloads an MP3 for a specific song (user-initiated, bypasses network restrictions)
    func downloadMP3(for filename: String) async -> Bool {
        guard !activeDownloads.contains(filename) else {
            Self.logger.debug("Download already in progress for \(filename)")
            return false
        }

        activeDownloads.insert(filename)
        Self.logger.info("User-triggered download: \(filename).mp3")

        let success = await downloader.downloadMP3(filename: filename)

        activeDownloads.remove(filename)

        if success {
            // update cache to available
            if let url = DataManager.getSongMP3(for: filename) {
                availabilityCache[filename] = .available(url)
            }
            Self.logger.info("Download complete: \(filename).mp3")
        } else {
            Self.logger.error("Download failed: \(filename).mp3")
        }

        return success
    }

    /// checks if a download is in progress for a filename
    func isDownloading(_ filename: String) -> Bool {
        activeDownloads.contains(filename)
    }

    // MARK: - Network Status

    var isConnected: Bool { networkMonitor.isConnected }
    var isExpensive: Bool { networkMonitor.isExpensive }
    var isConstrained: Bool { networkMonitor.isConstrained }
}
