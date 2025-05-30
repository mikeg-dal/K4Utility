//
//  TCPClient.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import Foundation
import Network

class TCPClient {
    // MARK: - Debug Control
    private static var debugUsageCount: Int = 0
    static var debugEnabled: Bool {
        return debugUsageCount > 0
    }
    static func enableDebug() {
        debugUsageCount += 1
    }
    static func disableDebug() {
        debugUsageCount = max(0, debugUsageCount - 1)
    }
    private static func log(_ message: String) {
        if debugEnabled {
            print("📡 TCPClient: \(message)")
        }
    }

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "TCPClientQueue")

    var onReceive: ((Data) -> Void)?
    /// Called when the connection is lost or cancelled
    var onDisconnect: (() -> Void)?
    
    /// Attempts to establish a connection and waits up to 5 seconds for success.
    /// Returns true if connection becomes ready, false otherwise.
    func connect(host: String, port: UInt16) -> Bool {
        // Semaphore to wait for ready or failure
        let semaphore = DispatchSemaphore(value: 0)
        var didConnect = false

        let nwEndpoint = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        connection = NWConnection(host: nwEndpoint, port: nwPort, using: .tcp)

        connection?.stateUpdateHandler = { [weak self] state in
            TCPClient.log("Connection state: \(state)")
            switch state {
            case .ready:
                didConnect = true
                semaphore.signal()
            case .failed(_), .cancelled:
                DispatchQueue.main.async {
                    self?.onDisconnect?()
                }
                semaphore.signal()
            default:
                break
            }
        }

        connection?.start(queue: queue)
        // Wait up to 5 seconds for the connection to become ready or fail
        let timeoutResult = semaphore.wait(timeout: .now() + 5)
        // Begin receiving regardless of timeout
        receive()
        return didConnect && timeoutResult == .success
    }

    func send(_ data: Data) {
        TCPClient.log("📤 Sending \(data.count) bytes -> \(data.map { String(format: "%02x", $0) }.joined())")
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                TCPClient.log("Send error: \(error)")
            }
        }))
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data = data {
                TCPClient.log("📡 Received \(data.count) bytes -> \(data.map { String(format: "%02x", $0) }.joined())")
                self?.onReceive?(data)
            }
            if error == nil {
                self?.receive() // Continue receiving
            }
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }
}
