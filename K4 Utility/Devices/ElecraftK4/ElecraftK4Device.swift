//
//  ElecraftK4Device.swift
//  K4Utility
//
//  Created by Mike Garcia on 5/21/2025.
//

import Foundation
import Combine

/// Manages the TCP/IP connection to an Elecraft K4 transceiver,
/// sends ASCII‐based commands, and publishes meter/frequency updates.
public class ElecraftK4Device: ObservableObject {
    // MARK: – Published Properties (for SwiftUI / Combine)

    /// Current frequency in Hertz (e.g. 7000000 for 7.000 MHz).
    @Published public var frequencyHz: Int = 0

    /// A human‐readable string of the current frequency (e.g. "7000000").
    @Published public var currentFrequencyDisplay: String = ""

    /// Indicates whether the socket is connected to the K4.
    @Published public  var isConnected: Bool = false

    /// If a connection error occurs, this will hold the localized message.
    @Published public  var connectionError: String?

    /// Forward power reading from the K4 (watts or protocol‐specific units).
    @Published public var forwardPower: Double = 0

    /// Reflected power reading from the K4 (watts or protocol‐specific units).
    @Published public var reflectedPower: Double = 0

    /// Standing wave ratio, computed from raw SWR tenths or parsed directly.
    @Published public var swr: Double = 1.0

    /// IP Address (string) for connecting to the K4.
    /// Updating this will automatically persist into `SettingsStore` (see init).
    @Published public var ipAddress: String

    /// TCP Port number for the K4 (default = 9200).
    @Published public var port: Int

    /// If true, print debug logs from all TCPClient reads/writes.
    @Published public var debugEnabled: Bool = false {
        didSet {
            if debugEnabled {
                TCPClient.enableDebug()
            } else {
                TCPClient.disableDebug()
            }
        }
    }

    // MARK: – Private/Internal State

    /// Reference to your shared SettingsStore (injected at init).
     let settingsStore: SettingsStore

    /// Any cancellables for Combine pipelines (e.g. persisting ip/port back to settings).
     var cancellables = Set<AnyCancellable>()

    /// The actual TCPClient instance (one per device).
     var client: TCPClient?

    /// A buffer for processing partial incoming data from the K4.
     var buffer = Data()

    /// A timer to poll periodically for status updates (e.g. AI5, TM1).
    /// You may choose to start/stop this when `isConnected` toggles.
     var pollingTimer: Timer?

    // MARK: – Initialization

    /// Designated initializer.
    /// Inject your `SettingsStore` (or other persistence) so that IP/Port are loaded and saved automatically.
     init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore

        // Load saved IP & port from SettingsStore
        let saved = settingsStore.settings.k4
        self.ipAddress = saved.ipAddress
        self.port = saved.port

        // When ipAddress changes, persist back into SettingsStore
        $ipAddress
            .dropFirst() // ignore the initial emit
            .sink { [weak self] newIP in
                self?.settingsStore.settings.k4.ipAddress = newIP
            }
            .store(in: &cancellables)

        // When port changes, persist back into SettingsStore
        $port
            .dropFirst()
            .sink { [weak self] newPort in
                self?.settingsStore.settings.k4.port = newPort
            }
            .store(in: &cancellables)
    }

    deinit {
        // Ensure cleanup if this instance is deallocated
        disconnect()
    }

    // MARK: – Public API

    /// Attempts to open a TCP connection to the Elecraft K4.
    /// On success, sets `isConnected = true` and begins polling.
    public func connect() {
        log("🚀 K4D: Starting connection to \(ipAddress):\(port)")

        // Create a fresh TCPClient
        client = TCPClient()
        client?.onReceive = handleIncoming(data:)
        client?.onDisconnect = handleDisconnect

        // Attempt to connect
        let success = client?.connect(host: ipAddress, port: UInt16(port)) ?? false
        if success {
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionError = nil
            }

            // Optionally: send any “initialization” commands once connected.
            sendCommand("FA;")  // Request frequency
            sendCommand("AI5;") // Request some status subset (e.g. forward/reflected)
            sendCommand("TM1;") // Request meter data
            startPollingTimer()
        } else {
            handleConnectionError()
        }
    }

    /// Stops polling, tears down the TCP connection, and sets `isConnected = false`.
    public func disconnect() {
        log("🔌 K4D: Disconnecting from \(ipAddress):\(port)")
        pollingTimer?.invalidate()
        pollingTimer = nil

        client?.disconnect()
        client?.onReceive = nil
        client?.onDisconnect = nil
        client = nil

        DispatchQueue.main.async {
            self.isConnected = false
        }
    }

    /// Sends a raw command string (e.g. “FA;”, “FRxxxx;”, etc.) to the K4.
    /// The string will be suffixed with CR before sending.
    public func sendCommand(_ command: String) {
        log("📤 K4D: Sending command: \(command)")
        guard let payload = (command + "\r").data(using: .utf8) else {
            log("⚠️ K4D: Failed to encode command: \(command)")
            return
        }
        client?.send(payload)
    }

    // MARK: – Private Helpers

    /// Starts a Timer that periodically requests updates (e.g. every 1 sec).
    private func startPollingTimer() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else { return }
            // TODO: Decide which periodic commands you need. For example:
            self.sendCommand("FA;") // update frequency every second (or adjust as needed)
            self.sendCommand("TM1;") // update forward/reflected/SWR
        }
    }

    /// Called by `TCPClient` whenever raw Data arrives.
    /// Append to `buffer` and parse out complete “;”-terminated messages.
     func handleIncoming(data: Data) {
        // Make sure data can be interpreted as UTF8 (or you can handle binary if needed)
        guard String(data: data, encoding: .utf8) != nil else { return }
        buffer.append(data)

        // Try splitting on “;” (semicolon) since K4 messages are “<CMD><payload>;”
        let bufferStr = String(decoding: buffer, as: UTF8.self)
        let segments = bufferStr.components(separatedBy: ";")

        // The last element in segments may be a partial message, so process all but the last
        for raw in segments.dropLast() {
            parseLine(raw + ";")
        }

        // Keep only the last partial chunk (if any) in `buffer`
        if let lastSemIndex = buffer.lastIndex(of: UInt8(ascii: ";")) {
            let nextIndex = buffer.index(after: lastSemIndex)
            buffer.removeSubrange(0..<nextIndex)
        }
    }

    /// Parses a single “<PREFIX><DATA>;” line from the K4.
    private func parseLine(_ lineWithSemicolon: String) {
        // Guaranteed to include the trailing “;”
        let trimmed = lineWithSemicolon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix(";") else { return }
        let content = String(trimmed.dropLast()) // remove “;”

        if content.hasPrefix("FA") {
            // FAxxxxxx  → frequency in Hz
            let freqStr = String(content.dropFirst(2))
            if let freq = Int(freqStr) {
                DispatchQueue.main.async {
                    self.frequencyHz = freq
                    self.currentFrequencyDisplay = freqStr
                    self.log("📥 K4D: Received FA → \(freqStr)")
                }
            }
        }
        else if content.hasPrefix("TM") {
            // TM<…> could be comma‐separated or fixed‐width.
            // Example comma: TM<x.y,<ref>,<alckey>,<swr>,…>
            let body = String(content.dropFirst(2))
            if body.contains(",") {
                let parts = body.split(separator: ",")
                if parts.count >= 4,
                   let fwd = Double(parts[0]),
                   let ref = Double(parts[1]),
                   let swrTenths = Double(parts[3]) {
                    DispatchQueue.main.async {
                        self.forwardPower = fwd
                        self.reflectedPower = ref
                        self.swr = swrTenths / 10.0
                    }
                }
            }
            else if body.count >= 12 {
                // Fixed‐width parsing: AAA (ALC), BBB (CMP), CCC (FWD), DDD (SWR)
                let str = body
                let refStr = String(str[str.index(str.startIndex, offsetBy: 3)..<str.index(str.startIndex, offsetBy: 6)])
                let fwdStr = String(str[str.index(str.startIndex, offsetBy: 6)..<str.index(str.startIndex, offsetBy: 9)])
                let swrStr = String(str[str.index(str.startIndex, offsetBy: 9)..<str.index(str.startIndex, offsetBy: 12)])
                if let fwd = Double(fwdStr),
                   let ref = Double(refStr),
                   let swrTenths = Double(swrStr) {
                    DispatchQueue.main.async {
                        self.forwardPower = fwd
                        self.reflectedPower = ref
                        self.swr = swrTenths / 10.0
                    }
                }
            }
        }
        else if content.hasPrefix("PO") {
            // POwwww  → total transmit power (reuse fwd or store separately)
            let valStr = String(content.dropFirst(2))
            if let total = Double(valStr) {
                DispatchQueue.main.async {
                    self.forwardPower = total
                }
            }
        }
        else if content.hasPrefix("SW") {
            // SWsss → SWR in tenths
            let valStr = String(content.dropFirst(2))
            if let tenths = Double(valStr) {
                DispatchQueue.main.async {
                    self.swr = tenths / 10.0
                }
            }
        }
        else {
            // TODO: Handle any other K4‐specific messages (e.g. AGC, mode changes, etc.)
            log("ℹ️ K4D: Unhandled prefix: \(content)")
        }
    }

    /// Logs to console only if `debugEnabled == true`.
    private func log(_ message: String) {
        if debugEnabled {
            print(message)
        }
    }

    /// Called if initial `connect(host:port:)` failed.
    private func handleConnectionError() {
        log("❌ K4D: Connection failed to \(ipAddress):\(port)")
        pollingTimer?.invalidate()
        pollingTimer = nil
        client?.disconnect()
        client = nil

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionError = "Unable to reach device at \(self.ipAddress):\(self.port)"
        }
    }

    /// Called if the TCPClient reports a disconnect (e.g. remote closed).
    private func handleDisconnect() {
        log("🔴 K4D: Connection lost")
        pollingTimer?.invalidate()
        pollingTimer = nil
        client = nil

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionError = "Connection lost"
        }
    }
}
