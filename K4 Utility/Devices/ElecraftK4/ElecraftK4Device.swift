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

    /// User-defined button labels for macros (e.g., "AI", "PO", etc.)
    @Published public var macroNames: [String] = Array(repeating: "", count: 3)

    /// Corresponding K4 command strings (e.g., "AI;", "PO;", etc.)
    @Published public var macroCommands: [String] = Array(repeating: "", count: 3)

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

    /// True if the K4 is operating in QRP mode (power < 10).
    @Published public var isQRPMode: Bool = false

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
        self.ipAddress = saved.device.ipAddress
        self.port = saved.device.port

        // Load user-defined macro labels and commands
        self.macroNames = settingsStore.settings.k4Macros.macroNames
        self.macroCommands = settingsStore.settings.k4Macros.macroCommands

        // Persist macroNames back into SettingsStore on change
        $macroNames
            .dropFirst()
            .sink { [weak self] newNames in
                self?.settingsStore.settings.k4Macros.macroNames = newNames
            }
            .store(in: &cancellables)

        // Persist macroCommands back into SettingsStore on change
        $macroCommands
            .dropFirst()
            .sink { [weak self] newCommands in
                self?.settingsStore.settings.k4Macros.macroCommands = newCommands
            }
            .store(in: &cancellables)

        // When ipAddress changes, persist back into SettingsStore
        $ipAddress
            .dropFirst() // ignore the initial emit
            .sink { [weak self] newIP in
                self?.settingsStore.settings.k4.device.ipAddress = newIP
            }
            .store(in: &cancellables)

        // When port changes, persist back into SettingsStore
        $port
            .dropFirst()
            .sink { [weak self] newPort in
                self?.settingsStore.settings.k4.device.port = newPort
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
        log("🔧 K4D: Initialized new TCPClient instance")
        client?.onReceive = handleIncoming(data:)
        client?.onDisconnect = handleDisconnect

        // Attempt to connect
        let success = client?.connect(host: ipAddress, port: UInt16(port)) ?? false
        if success {
            log("✅ K4D: TCPClient.connect(host:\(ipAddress), port:\(port)) succeeded")
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionError = nil
            }

            // Optionally: send any “initialization” commands once connected.
            log("ℹ️ K4D: Sending initialization command FA;")
            sendCommand("FA;")  // Request frequency
            log("ℹ️ K4D: Sending initialization command AI5;")
            sendCommand("AI5;") // Request some status subset (e.g. forward/reflected)
            log("ℹ️ K4D: Sending initialization command TM1;")
            sendCommand("TM1;") // Request meter data
            log("ℹ️ K4D: Sending initialization command PC;")
            sendCommand("PC;") // Request current power setting
            startPollingTimer()
        } else {
            log("❌ K4D: TCPClient.connect(host:\(ipAddress), port:\(port)) failed")
            handleConnectionError()
        }
    }

    /// Stops polling, tears down the TCP connection, and sets `isConnected = false`.
    public func disconnect() {
        log("🔌 K4D: Disconnecting from \(ipAddress):\(port)")
        log("🛑 K4D: Teardown TCPClient and clear state")
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

    /// Initiates the LP Tune process on the K4 transceiver.
    public func startTune() {
        // Send the command to begin tuning (TU2;)
        sendCommand("TU2;")
    }

    /// Stops the LP Tune  process on the K4 transceiver.
    public func stopTune() {
        // Send the command to end tuning (TU0;)
        sendCommand("TU0;")
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
        if let incomingStr = String(data: data, encoding: .utf8) {
            log("📥 K4D: Raw incoming data chunk: '\(incomingStr)'")
        }
        // Make sure data can be interpreted as UTF8 (or you can handle binary if needed)
        guard String(data: data, encoding: .utf8) != nil else { return }
        buffer.append(data)

        // Try splitting on “;” (semicolon) since K4 messages are “<CMD><payload>;”
        let bufferStr = String(decoding: buffer, as: UTF8.self)
        log("📥 K4D: Buffer string before splitting: '\(bufferStr)'")
        let segments = bufferStr.components(separatedBy: ";")

        // The last element in segments may be a partial message, so process all but the last
        for raw in segments.dropLast() {
            log("📥 K4D: Complete message to parse: '\(raw);'")
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

        log("🔍 K4D: parseLine received content: '\(content)'")

        if content.hasPrefix("FA") {
            // FAxxxxxx  → frequency in Hz
            let freqStr = String(content.dropFirst(2))
            if let freq = Int(freqStr) {
                log("ℹ️ K4D: Parsed FA → frequency = \(freqStr)")
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
            log("ℹ️ K4D: TM‐prefix message = '\(content)'")
            let body = String(content.dropFirst(2))
            if body.contains(",") {
                let parts = body.split(separator: ",")
                log("📊 K4D: TM CSV parts = \(parts)")
                if parts.count >= 4,
                   let fwd = Double(parts[0]),
                   let ref = Double(parts[1]),
                   let swrTenths = Double(parts[3]) {
                    DispatchQueue.main.async {
                        self.forwardPower = self.isQRPMode ? fwd / 10.0 : fwd
                        self.reflectedPower = self.isQRPMode ? ref / 10.0 : ref
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
                log("📊 K4D: TM fixed-width segments fwdStr=\(fwdStr), refStr=\(refStr), swrStr=\(swrStr)")
                if let fwd = Double(fwdStr),
                   let ref = Double(refStr),
                   let swrTenths = Double(swrStr) {
                    DispatchQueue.main.async {
                        self.forwardPower = self.isQRPMode ? fwd / 10.0 : fwd
                        self.reflectedPower = self.isQRPMode ? ref / 10.0 : ref
                        self.swr = swrTenths / 10.0
                    }
                }
            }
        }
        else if content.hasPrefix("PO") {
            // POwwww  → total transmit power (reuse fwd or store separately)
            let valStr = String(content.dropFirst(2))
            if let total = Double(valStr) {
                log("ℹ️ K4D: PO‐prefix message = '\(content)'")
                DispatchQueue.main.async {
                    self.forwardPower = total / 10.0
                }
            }
        }
        else if content.hasPrefix("SW") {
            // SWsss → SWR in tenths
            let valStr = String(content.dropFirst(2))
            if let tenths = Double(valStr) {
                log("ℹ️ K4D: SW‐prefix message = '\(content)'")
                DispatchQueue.main.async {
                    self.swr = tenths / 10.0
                }
            }
        }
        else if content.hasPrefix("PC") {
            let valStr = String(content.dropFirst(2).prefix(3)) // Extract "nnn"
            if let value = Int(valStr) {
                DispatchQueue.main.async {
                    self.isQRPMode = value < 10
                    self.log("🔌 K4D: Power level updated = \(value) → isQRPMode = \(self.isQRPMode)")
                }
            }
        }
        else {
            log("⚠️ K4D: Unhandled prefix encountered")
            // TODO: Handle any other K4‐specific messages (e.g. AGC, mode changes, etc.)
            log("ℹ️ K4D: Unhandled prefix: \(content)")
        }
    }

    /// Logs to console only if `debugEnabled == true`, including a timestamp.
    private func log(_ message: String) {
        if debugEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] \(message)")
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
    /// A formatted string representing the frequency in MHz (e.g. "7.000").
    public var formattedFrequency: String {
        guard frequencyHz > 0 else { return "" }
        let mhz = Double(frequencyHz) / 1_000_000.0
        return String(format: "%.3f", mhz)
    }

    /// Returns the macro label at a given index, or a fallback label if unavailable.
    public func macroLabel(at index: Int) -> String {
        guard index >= 0 && index < macroNames.count else {
            return "Macro \(index + 1)"
        }
        return macroNames[index].isEmpty ? "Macro \(index + 1)" : macroNames[index]
    }
}
