//
//  ResourceDownloader.swift
//  songbook
//
//  For downloading PDF and MP3 resources with queue and retry logic.
//

import Foundation
import os.log

actor ResourceDownloader {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ResourceDownloader")
    
    enum ResourceType: String, Sendable {
        case pdf
        case mp3
    }
    
    struct DownloadTask: Sendable {
        let filename: String
        let type: ResourceType
        var retryCount: Int = 0
        var networkWaitCount: Int = 0
    }
    
    private let networkMonitor: NetworkMonitor
    private let basePDFURL: String
    private let baseMP3URL: String
    
    private var queue: [DownloadTask] = []
    private var isProcessing = false
    private let maxRetries = 3
    private let maxNetworkWaits = 10  // give up after ~50 seconds of no network
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
    
    init(networkMonitor: NetworkMonitor, basePDFURL: String, baseMP3URL: String) {
        self.networkMonitor = networkMonitor
        self.basePDFURL = basePDFURL
        self.baseMP3URL = baseMP3URL
    }
    
    /// queues a resource for download (deduplicates)
    func queueDownload(filename: String, type: ResourceType) {
        // skip if already queued
        if queue.contains(where: { $0.filename == filename && $0.type == type }) {
            return
        }
        
        queue.append(DownloadTask(filename: filename, type: type))
        Self.logger.debug("Queued \(type.rawValue) download: \(filename)")
    }
    
    /// processes all queued downloads
    func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true
        
        Self.logger.info("Processing download queue (\(self.queue.count) items)")
        
        while !queue.isEmpty {
            var task = queue.removeFirst()
            
            // check network - give up after max waits to avoid infinite loop
            if !networkMonitor.isConnected {
                task.networkWaitCount += 1
                if task.networkWaitCount >= maxNetworkWaits {
                    Self.logger.error("Giving up on \(task.filename) after \(self.maxNetworkWaits) network waits")
                    continue
                }
                Self.logger.warning("No network - requeuing \(task.filename) (wait \(task.networkWaitCount)/\(self.maxNetworkWaits))")
                queue.append(task)
                try? await Task.sleep(for: .seconds(5))
                continue
            }
            
            // log metered status (for future: prompt user)
            if networkMonitor.isExpensive {
                Self.logger.info("Metered connection detected for download: \(task.filename)")
            }
            
            let success = await download(task: task)
            
            if !success && task.retryCount < maxRetries {
                var retryTask = task
                retryTask.retryCount += 1
                queue.append(retryTask)
                Self.logger.debug("Retry \(retryTask.retryCount) queued for \(task.filename)")
            }
        }
        
        isProcessing = false
        Self.logger.info("Download queue processing complete")
    }
    
    private func download(task: DownloadTask) async -> Bool {
        let baseURL = task.type == .pdf ? basePDFURL : baseMP3URL
        let ext = task.type.rawValue
        
        guard let url = URL(string: "\(baseURL)\(task.filename).\(ext)") else {
            Self.logger.error("Invalid URL for \(task.filename).\(ext)")
            return false
        }
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let subdir = task.type == .pdf ? "pdfs" : "audio"
        let destinationDir = appSupport.appendingPathComponent(subdir)
        let destination = destinationDir.appendingPathComponent("\(task.filename).\(ext)")
        
        // skip if already exists
        if FileManager.default.fileExists(atPath: destination.path) {
            Self.logger.debug("File already exists: \(task.filename).\(ext)")
            return true
        }
        
        do {
            // ensure directory exists
            try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                Self.logger.error("Bad response for \(task.filename).\(ext)")
                return false
            }
            
            try data.write(to: destination)
            Self.logger.info("Downloaded \(task.filename).\(ext)")
            return true
            
        } catch {
            Self.logger.error("Download failed for \(task.filename).\(ext): \(error.localizedDescription)")
            return false
        }
    }
    
    /// returns count of pending downloads
    var pendingCount: Int {
        queue.count
    }
}

