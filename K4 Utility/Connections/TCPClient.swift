//
//  TCPClient.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import Foundation
import Network

/// Thread-safe wrapper for a boolean value
private final class AtomicBool {
    private let lock = NSLock()
    private var _value: Bool
    
    init(_ initialValue: Bool) {
        _value = initialValue
    }
    
    func getValue() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
    
    func compareAndSet(from expected: Bool, to newValue: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _value == expected {
            _value = newValue
            return true
        }
        return false
    }
}

/// A modern TCP client wrapper using Network.framework's NWConnection with async/await support,
/// proper error handling, and automatic retry logic. Includes optional debug logging.
class TCPClient {
    // MARK: - Error Types
    
    enum TCPError: LocalizedError {
        case connectionTimeout
        case networkUnreachable
        case connectionRefused
        case unknownError(Error)
        
        var errorDescription: String? {
            switch self {
            case .connectionTimeout:
                return "Connection timed out. Check if device is powered on and network is reachable."
            case .networkUnreachable:
                return "Network unreachable. Check your network connection and device IP address."
            case .connectionRefused:
                return "Connection refused. Verify the device is accepting connections on this port."
            case .unknownError(let error):
                return "Connection failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Connection State
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case failed(TCPError)
    }
    
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
    private static func log(_ message: String) {
        if debugEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] 📡 TCPClient: \(message)")
        }
    }
    
    // MARK: - Connection Properties
    
    /// The underlying Network.framework connection used for TCP communication.
    private var connection: NWConnection?
    
    /// The dispatch queue on which the NWConnection events are processed.
    private let queue = DispatchQueue(label: "TCPClientQueue", qos: .userInitiated)
    
    /// Current connection state
    @MainActor
    private var _connectionState: ConnectionState = .disconnected
    
    /// Callback invoked when data is received from the server.
    var onReceive: ((Data) -> Void)?
    
    /// Callback invoked when the connection is lost or cancelled.
    var onDisconnect: (() -> Void)?
    
    /// Connection state callback for UI updates
    var onStateChange: ((ConnectionState) -> Void)?
    
    // MARK: - Public API: Connection Management
    
    /// Current connection state (main actor isolated)
    @MainActor
    var connectionState: ConnectionState {
        return _connectionState
    }
    
    /// Sets connection state and notifies observers (main actor isolated)
    @MainActor
    private func setConnectionState(_ newState: ConnectionState) {
        _connectionState = newState
        onStateChange?(newState)
    }
    
    /// Attempts to establish a TCP connection to the specified host and port with retry logic.
    ///
    /// - Parameters:
    ///   - host: The hostname or IP address to connect to.
    ///   - port: The TCP port number.
    ///   - timeout: Connection timeout in seconds (default: 5.0)
    ///   - maxRetries: Maximum number of retry attempts (default: 0)
    /// - Returns: `true` if connection was successful, `false` otherwise
    /// - Throws: TCPError if connection ultimately fails
    func connect(host: String, port: UInt16, timeout: TimeInterval = 5.0, maxRetries: Int = 0) async throws -> Bool {
        Self.log("Starting connection to \(host):\(port) with \(maxRetries) max retries")
        
        await setConnectionState(.connecting)
        
        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = min(1.0 * pow(1.5, Double(attempt - 1)), 5.0) // Gentler backoff, max 5 seconds
                Self.log("Retry attempt \(attempt) after \(delay)s delay")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            do {
                let success = try await attemptConnection(host: host, port: port, timeout: timeout)
                if success {
                    Self.log("Connection successful on attempt \(attempt + 1)")
                    await setConnectionState(.connected)
                    startReceiving()
                    return true
                }
            } catch {
                Self.log("Connection attempt \(attempt + 1) failed: \(error)")
                if attempt == maxRetries {
                    let tcpError = mapError(error)
                    await setConnectionState(.failed(tcpError))
                    throw tcpError
                }
                // Continue to next retry
            }
        }
        
        let error = TCPError.connectionTimeout
        await setConnectionState(.failed(error))
        throw error
    }
    
    /// Attempts a single connection without retry logic
    private func attemptConnection(host: String, port: UInt16, timeout: TimeInterval) async throws -> Bool {
        return try await withThrowingTaskGroup(of: Bool.self) { group in
            // Connection task
            group.addTask {
                return await self.performConnection(host: host, port: port)
            }
            
            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TCPError.connectionTimeout
            }
            
            // Return the first result and cancel other tasks
            defer { 
                group.cancelAll()
                // Clean up connection on timeout/failure
                if self.connection?.state != .ready {
                    self.connection?.cancel()
                    self.connection = nil
                }
            }
            return try await group.next() ?? false
        }
    }
    
    /// Performs the actual NWConnection setup and waits for ready state
    private func performConnection(host: String, port: UInt16) async -> Bool {
        return await withCheckedContinuation { continuation in
            let nwEndpoint = NWEndpoint.Host(host)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: false)
                return
            }
            
            // Configure TCP options for better performance
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.noDelay = true
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 30 // Send keepalive after 30 seconds of inactivity
            tcpOptions.keepaliveInterval = 5 // Send keepalives every 5 seconds
            tcpOptions.keepaliveCount = 3 // Give up after 3 failed keepalives
            
            let parameters = NWParameters(tls: nil, tcp: tcpOptions)
            connection = NWConnection(host: nwEndpoint, port: nwPort, using: parameters)
            
            // Use thread-safe atomic boolean
            let hasResumed = AtomicBool(false)
            
            connection?.stateUpdateHandler = { [weak self] state in
                Self.log("Connection state changed to: \(state)")
                
                switch state {
                case .ready:
                    if hasResumed.compareAndSet(from: false, to: true) {
                        continuation.resume(returning: true)
                    }
                    
                case .failed(let error):
                    Self.log("Connection failed with error: \(error)")
                    // Always clean up failed connection
                    self?.connection?.cancel()
                    self?.connection = nil
                    
                    if hasResumed.compareAndSet(from: false, to: true) {
                        continuation.resume(returning: false)
                    } else {
                        // Connection was established but later failed
                        Task { @MainActor in
                            self?.setConnectionState(.failed(self?.mapError(error) ?? .unknownError(error)))
                            self?.onDisconnect?()
                        }
                    }
                    
                case .cancelled:
                    Self.log("Connection was cancelled")
                    // Clean up cancelled connection
                    self?.connection = nil
                    
                    if hasResumed.compareAndSet(from: false, to: true) {
                        continuation.resume(returning: false)
                    } else {
                        Task { @MainActor in
                            self?.setConnectionState(.disconnected)
                            self?.onDisconnect?()
                        }
                    }
                case .waiting(let error):
                    Self.log("Connection waiting: \(error)")
                case .preparing:
                    Self.log("Connection preparing...")
                case .setup:
                    Self.log("Connection setup...")
                @unknown default:
                    Self.log("Unknown connection state: \(state)")
                }
            }
            
            connection?.start(queue: queue)
        }
    }
    
    /// Maps NWError to TCPError for better user experience
    private func mapError(_ error: Error) -> TCPError {
        if let nwError = error as? NWError {
            switch nwError {
            case .posix(let posixError):
                switch posixError {
                case .ECONNREFUSED:
                    return .connectionRefused
                case .ENETUNREACH, .EHOSTUNREACH:
                    return .networkUnreachable
                case .ETIMEDOUT:
                    return .connectionTimeout
                default:
                    return .unknownError(error)
                }
            default:
                return .unknownError(error)
            }
        }
        return .unknownError(error)
    }
    
    /// Sends the provided data over the TCP connection.
    ///
    /// - Parameter data: The `Data` to send to the connected server.
    func send(_ data: Data) {
        guard connection?.state == .ready else {
            Self.log("⚠️ Attempted to send data on non-ready connection")
            return
        }
        
        Self.log("📤 Sending \(data.count) bytes")
        if Self.debugEnabled {
            let hexString = data.map { String(format: "%02x", $0) }.joined()
            Self.log("📤 Data: \(hexString)")
        }
        
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                Self.log("❌ Send error: \(error)")
            }
        }))
    }
    
    /// Begins an asynchronous receive loop to handle incoming data from the server.
    private func startReceiving() {
        receive()
    }
    
    /// Recursive receive method that continues until connection is closed
    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                Self.log("📥 Received \(data.count) bytes")
                if Self.debugEnabled {
                    let hexString = data.map { String(format: "%02x", $0) }.joined()
                    Self.log("📥 Data: \(hexString)")
                }
                
                // Call receive handler on main queue for thread safety
                DispatchQueue.main.async {
                    self?.onReceive?(data)
                }
            }
            
            if let error = error {
                Self.log("❌ Receive error: \(error)")
                return
            }
            
            if isComplete {
                Self.log("📥 Connection completed by remote")
                return
            }
            
            // Continue receiving
            self?.receive()
        }
    }
    
    /// Cancels the TCP connection and cleans up resources.
    func disconnect() {
        Self.log("🔌 Disconnecting")
        connection?.cancel()
        connection = nil
        
        Task { @MainActor in
            setConnectionState(.disconnected)
        }
    }
    
    /// Check if connection is currently active
    var isConnected: Bool {
        return connection?.state == .ready
    }
}