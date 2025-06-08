//
//  TCPClient.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import Foundation
import Network

/// A lightweight TCP client wrapper using Network.framework's NWConnection,
/// providing methods to connect, send, receive data, and handle disconnections.
/// Includes optional debug logging that can be enabled/disabled globally.
class TCPClient {
    // MARK: - Debug Control

    /// Tracks how many components have requested debug logging to be enabled.
    private static var debugUsageCount: Int = 0

    /// Indicates whether debug logging is currently enabled (true if any user has enabled).
    static var debugEnabled: Bool {
        return debugUsageCount > 0
    }

    /// Increments the debug usage count, enabling detailed logging if count > 0.
    static func enableDebug() {
        debugUsageCount += 1
    }

    /// Decrements the debug usage count, disabling logging when count reaches 0.
    static func disableDebug() {
        debugUsageCount = max(0, debugUsageCount - 1)
    }

    /// Logs a debug message to the console if debug logging is enabled.
    ///
    /// - Parameter message: The message to print when debugEnabled is true.
    private static func log(_ message: String) {
        if debugEnabled {
            print("📡 TCPClient: \(message)")
        }
    }

    // MARK: - Connection Properties

    /// The underlying Network.framework connection used for TCP communication.
    private var connection: NWConnection?

    /// The dispatch queue on which the NWConnection events are processed.
    private let queue = DispatchQueue(label: "TCPClientQueue")

    /// Callback invoked when data is received from the server.
    var onReceive: ((Data) -> Void)?

    /// Callback invoked when the connection is lost or cancelled.
    var onDisconnect: (() -> Void)?

    // MARK: - Public API: Connection Management

    /// Attempts to establish a TCP connection to the specified host and port,
    /// waiting up to 5 seconds for the connection to become ready.
    ///
    /// - Parameters:
    ///   - host: The hostname or IP address to connect to.
    ///   - port: The TCP port number.
    /// - Returns: `true` if the connection was successfully established within 5 seconds; `false` otherwise.
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

    /// Sends the provided data over the TCP connection.
    ///
    /// - Parameter data: The `Data` to send to the connected server.
    func send(_ data: Data) {
        TCPClient.log("📤 Sending \(data.count) bytes -> \(data.map { String(format: "%02x", $0) }.joined())")
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                TCPClient.log("Send error: \(error)")
            }
        }))
    }

    // MARK: - Private API: Receiving Data

    /// Begins an asynchronous receive loop to handle incoming data from the server.
    /// Calls `onReceive` with each chunk of data, then continues waiting for more.
    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data = data {
                TCPClient.log("📡 Received \(data.count) bytes -> \(data.map { String(format: "%02x", $0) }.joined())")
                self?.onReceive?(data)
            }
            if error == nil {
                // Continue receiving subsequent data
                self?.receive()
            }
        }
    }

    /// Cancels the TCP connection and cleans up resources.
    func disconnect() {
        connection?.cancel()
        connection = nil
    }
}
