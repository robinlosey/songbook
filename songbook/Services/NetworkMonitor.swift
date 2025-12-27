//
//  NetworkMonitor.swift
//  songbook
//
//  Wraps NWPathMonitor to track network connectivity and metered status.
//

import Foundation
import Network
import os.log

@Observable
final class NetworkMonitor: @unchecked Sendable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NetworkMonitor")
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    
    private(set) var isConnected: Bool = true
    private(set) var isExpensive: Bool = false  // cellular/metered connection
    private(set) var isConstrained: Bool = false // low data mode
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.isConstrained = path.isConstrained
                
                Self.logger.debug("Network status: connected=\(path.status == .satisfied), expensive=\(path.isExpensive), constrained=\(path.isConstrained)")
            }
        }
    }
    
    func start() {
        monitor.start(queue: queue)
        Self.logger.info("Network monitoring started")
    }
    
    func stop() {
        monitor.cancel()
        Self.logger.info("Network monitoring stopped")
    }
}

