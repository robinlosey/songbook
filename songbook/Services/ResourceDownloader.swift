//
//  ResourceDownloader.swift
//  songbook
//
//  Downloads PDF and MP3 resources with priority queues, parallel execution,
//  and network-aware logic.
//

import Foundation
import os.log

actor ResourceDownloader {
    static let shared = ResourceDownloader()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ResourceDownloader")
    
    enum ResourceType: String, Sendable {
        case pdf
        case mp3
    }
    
    struct DownloadTask: Sendable {
        let filename: String
        let type: ResourceType
        var retryCount: Int = 0
    }
    
    enum DownloadResult: Sendable {
        case success
        case failure
        case skipped  // e.g., already exists
    }
    
    private let networkMonitor: NetworkMonitor
    private let basePDFURL: String
    private let baseMP3URL: String
    
    // separate queues for priority handling
    private var pdfQueue: [DownloadTask] = []
    private var mp3Queue: [DownloadTask] = []
    
    private var isProcessingPDFs = false
    private var isProcessingMP3s = false
    
    private let maxRetries = 3
    private let maxConcurrent = 4
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
    
    // singleton initializer
    private init() {
        self.networkMonitor = NetworkMonitor.shared
        self.basePDFURL = DataManager.shared.pdfDownloadURL
        self.baseMP3URL = DataManager.shared.mp3DownloadURL
    }
    
    // testing initializer
    init(networkMonitor: NetworkMonitor, basePDFURL: String, baseMP3URL: String) {
        self.networkMonitor = networkMonitor
        self.basePDFURL = basePDFURL
        self.baseMP3URL = baseMP3URL
    }
    
    // MARK: - Queue Management
    
    /// queues a resource for download (deduplicates)
    func queueDownload(filename: String, type: ResourceType) {
        let queue = type == .pdf ? pdfQueue : mp3Queue
        
        if queue.contains(where: { $0.filename == filename }) {
            return
        }
        
        let task = DownloadTask(filename: filename, type: type)
        if type == .pdf {
            pdfQueue.append(task)
        } else {
            mp3Queue.append(task)
        }
        
        Self.logger.debug("Queued \(type.rawValue): \(filename)")
    }
    
    var pendingPDFCount: Int { pdfQueue.count }
    var pendingMP3Count: Int { mp3Queue.count }
    
    // MARK: - Processing
    
    /// processes all queued PDFs (high priority, always runs)
    func processPDFs() async {
        guard !isProcessingPDFs else { return }
        isProcessingPDFs = true
        
        Self.logger.info("Processing PDF queue (\(self.pdfQueue.count) items)")
        
        // take items and clear queue (actor-safe)
        let tasks = pdfQueue
        pdfQueue.removeAll()
        
        let failures = await processQueue(tasks, type: .pdf)
        pdfQueue.append(contentsOf: failures)
        
        isProcessingPDFs = false
        Self.logger.info("PDF queue processing complete")
    }
    
    /// processes all queued MP3s (low priority, network-aware)
    func processMP3s() async {
        guard !isProcessingMP3s else { return }
        
        // skip on expensive/constrained connections
        if networkMonitor.isExpensive || networkMonitor.isConstrained {
            Self.logger.info("Skipping MP3 downloads on metered/constrained connection (\(self.mp3Queue.count) deferred)")
            return
        }
        
        isProcessingMP3s = true
        
        Self.logger.info("Processing MP3 queue (\(self.mp3Queue.count) items)")
        
        // take items and clear queue (actor-safe)
        let tasks = mp3Queue
        mp3Queue.removeAll()
        
        let failures = await processQueue(tasks, type: .mp3)
        mp3Queue.append(contentsOf: failures)
        
        isProcessingMP3s = false
        Self.logger.info("MP3 queue processing complete")
    }
    
    /// processes tasks with parallel downloads, returns failed tasks for retry
    private func processQueue(_ tasks: [DownloadTask], type: ResourceType) async -> [DownloadTask] {
        var pending = tasks
        var failedTasks: [DownloadTask] = []
        
        // process in batches for parallel execution
        while !pending.isEmpty {
            // check network before each batch
            guard networkMonitor.isConnected else {
                Self.logger.warning("No network - pausing \(type.rawValue) downloads")
                try? await Task.sleep(for: .seconds(5))
                continue
            }
            
            // for MP3s, re-check metered status
            if type == .mp3 && (networkMonitor.isExpensive || networkMonitor.isConstrained) {
                Self.logger.info("Connection became metered - stopping MP3 downloads")
                // return remaining + failures for re-queue
                failedTasks.append(contentsOf: pending)
                break
            }
            
            // take up to maxConcurrent tasks
            let batchSize = min(maxConcurrent, pending.count)
            let batch = Array(pending.prefix(batchSize))
            pending.removeFirst(batchSize)
            
            // download batch in parallel
            await withTaskGroup(of: (DownloadTask, DownloadResult).self) { group in
                for task in batch {
                    group.addTask {
                        let result = await self.download(task: task)
                        return (task, result)
                    }
                }
                
                for await (task, result) in group {
                    if case .failure = result, task.retryCount < self.maxRetries {
                        var retryTask = task
                        retryTask.retryCount += 1
                        failedTasks.append(retryTask)
                        Self.logger.debug("Will retry \(task.filename) (attempt \(retryTask.retryCount))")
                    }
                }
            }
        }
        
        if !failedTasks.isEmpty {
            Self.logger.info("Returning \(failedTasks.count) failed \(type.rawValue) downloads for retry")
        }
        
        return failedTasks
    }
    
    // MARK: - Single File Download (User-Triggered)
    
    /// downloads a single MP3 immediately, bypassing network restrictions
    func downloadMP3(filename: String) async -> Bool {
        let task = DownloadTask(filename: filename, type: .mp3)
        
        // remove from queue if present
        mp3Queue.removeAll { $0.filename == filename }
        
        let result = await download(task: task)
        return result == .success
    }
    
    // MARK: - Core Download
    
    private func download(task: DownloadTask) async -> DownloadResult {
        let baseURL = task.type == .pdf ? basePDFURL : baseMP3URL
        let ext = task.type.rawValue
        
        guard let url = URL(string: "\(baseURL)\(task.filename).\(ext)") else {
            Self.logger.error("Invalid URL for \(task.filename).\(ext)")
            return .failure
        }
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let subdir = task.type == .pdf ? "pdfs" : "audio"
        let destinationDir = appSupport.appendingPathComponent(subdir)
        let destination = destinationDir.appendingPathComponent("\(task.filename).\(ext)")
        
        // skip if already exists
        if FileManager.default.fileExists(atPath: destination.path) {
            Self.logger.debug("Already exists: \(task.filename).\(ext)")
            return .skipped
        }
        
        do {
            try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                Self.logger.error("Bad response (\(statusCode)) for \(task.filename).\(ext)")
                return .failure
            }
            
            try data.write(to: destination)
            Self.logger.info("Downloaded \(task.filename).\(ext)")
            return .success
            
        } catch {
            Self.logger.error("Download failed for \(task.filename).\(ext): \(error.localizedDescription)")
            return .failure
        }
    }
    
    // MARK: - MP3 Availability Check
    
    /// checks if an MP3 exists on the server (HEAD request)
    func checkMP3Exists(filename: String) async -> Bool {
        guard let url = URL(string: "\(baseMP3URL)\(filename).mp3") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
}
