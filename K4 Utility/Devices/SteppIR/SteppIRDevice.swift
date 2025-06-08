/// Tracks a pending user-requested direction change, if any.
//
//  SteppIRDevice.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import Foundation
import Combine
import SwiftUI  // for SettingsStore access

/// Manages TCP/IP communication and control for a SteppIR antenna controller.
/// Publishes frequency, direction, tuning, tracking, and connection status, and
/// provides methods to send frequency updates, home, auto-track, and calibration commands.
class SteppIRDevice: ObservableObject {
/// Supported SteppIR direction modes.
enum SteppIRDirection: String {
    case normal = "Normal"
    case deg180 = "180"
    case bidirectional = "BID"
}

/// Supported command codes for SteppIR protocol.
enum SteppIRCommand: UInt8 {
    case setFrequency     = 0x31  // '1'
    case enableTracking   = 0x52  // 'R'
    case home             = 0x53  // 'S'
    case disableTracking  = 0x55  // 'U'
    case calibrate        = 0x56  // 'V'
}
// MARK: – Published Properties (State)

/// The current frequency in Hertz to set on the SteppIR controller.
@Published var frequencyHz: Int = 0

/// The current direction mode.
@Published var direction: SteppIRDirection = .normal

/// Whether auto-tracking is enabled (true) or why did  (false).
@Published var isTrackingEnabled: Bool = false

/// Indicates if the TCP connection to the SteppIR is established.
@Published var isConnected: Bool = false

/// Holds a human-readable error message if a connection or communication error occurs.
@Published var connectionError: String?

/// Indicates the tuning status: true if tuning is in progress, false otherwise.
@Published var tuningStatus: Bool = false

/// Enables or disables debug logging (prints to console when true).
@Published var debugEnabled: Bool = false

// MARK: – Private Helpers: Debug Logging

/// Enables suppression of frequency updates while direction change is pending.
private var pendingDirection: SteppIRDirection? = nil

/// Tracks whether the current direction change was manually triggered by user.
private var isManuallyChangingDirection: Bool = false
    
    
// MARK: – Private Helpers: Debug Logging

/// Prints a debug message with a timestamp when `debugEnabled` is true.
///
/// - Parameter message: The debug message to print.
private func log(_ message: String) {
    if debugEnabled {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] \(message)")
    }
}

// MARK: – Networking Properties

/// The TCP client used to communicate with the SteppIR controller.
private var client: TCPClient?

/// Buffer accumulating raw incoming bytes until a complete frame (terminated by 0x0D) is detected.
private var buffer = Data()

/// Timer responsible for periodic polling of the SteppIR status.
private var pollingTimer: Timer?

// MARK: – Configuration & Persistence

/// The IP address of the SteppIR controller, stored in `SettingsStore`.
@Published var ipAddress: String = ""

/// The TCP port number of the SteppIR controller, stored in `SettingsStore`.
@Published var port: Int = 0

/// Shared settings store for persisting IP and port values.
private var settingsStore: SettingsStore

/// Combine cancellables for persisting setting changes.
private var cancellables = Set<AnyCancellable>()

/// Stored reference to the K4 device for frequency updates
private let k4Device: ElecraftK4Device

// MARK: – Initialization

/// Creates a new `SteppIRDevice` using the provided `SettingsStore` and K4 device.
/// Loads saved IP and port from the store and sets up persistence.
/// Subscribes to K4 frequency updates to forward to SteppIR when tracking is enabled.
///
/// - Parameters:
///   - settingsStore: Shared settings store containing `steppIR` settings.
///   - k4Device: The ElecraftK4Device to observe for automatic frequency sync.
init(settingsStore: SettingsStore, k4Device: ElecraftK4Device) {
    self.settingsStore = settingsStore
    self.k4Device = k4Device

    // Load saved IP address and port
    let saved = settingsStore.settings.steppIR.device
    self.ipAddress = saved.ipAddress
    self.port = saved.port

    // Persist IP address changes back to SettingsStore
    $ipAddress
        .dropFirst()
        .sink { [weak self] new in
            self?.settingsStore.settings.steppIR.device.ipAddress = new
        }
        .store(in: &cancellables)

    // Persist port changes back to SettingsStore
    $port
        .dropFirst()
        .sink { [weak self] new in
            self?.settingsStore.settings.steppIR.device.port = new
        }
        .store(in: &cancellables)

    // Subscribe to K4 frequency updates to log receipt (do not send update)
    k4Device.$frequencyHz
        .removeDuplicates()
        .sink { [weak self] newFreq in
            guard let self = self, self.isConnected else {
                self?.log("SteppIR: Skipping frequency update because not connected")
                return
            }
            self.log("SteppIR: Received K4 freq \(newFreq), isTrackingEnabled = \(self.isTrackingEnabled)")
        }
        .store(in: &cancellables)

    // Debounce K4 frequency changes and send one update when auto-tracking is enabled
    k4Device.$frequencyHz
        .removeDuplicates()
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self, weak k4Device] newFreq in
            guard let self = self, let k4 = k4Device, self.isConnected, self.isTrackingEnabled else {
                return
            }
            let freqHz = k4.frequencyHz
            self.sendFrequencyUpdate(freqHz)
        }
        .store(in: &cancellables)

    // When direction changes while auto-tracking is on, send an update
    $direction
        .dropFirst()
        .sink { [weak self, weak k4Device] newDir in
            guard let self = self, let k4 = k4Device, self.isConnected, self.isTrackingEnabled else {
                return
            }
            if self.isManuallyChangingDirection {
                self.sendFrequencyUpdate(k4.frequencyHz)
            }
        }
        .store(in: &cancellables)
}

deinit {
    // Ensure connection is closed if object deallocates
    disconnect()
}

// MARK: – Public API: Connection Management

/// Attempts to open a TCP connection to the SteppIR controller and starts polling.
///
/// On success:
/// - Sets `isConnected = true`.
/// - Schedules a timer to poll status every 2 seconds.
/// On failure:
/// - Calls `handleConnectionError()` to record the error and clean up.
func connect() {
    log("🔗 SteppIR: Attempting to connect to \(ipAddress):\(port)")
    client = TCPClient()
    log("🔧 SteppIR: Initialized new TCPClient instance")
    client?.onReceive = handleIncoming(data:)
    client?.onDisconnect = handleDisconnect

    let success = client?.connect(host: ipAddress, port: UInt16(port)) ?? false
    if success {
        log("✅ SteppIR: TCPClient.connect(host:\(ipAddress), port:\(port)) succeeded")
        DispatchQueue.main.async {
            self.isConnected = true
        }
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollStatus()
        }
        if let timer = pollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    } else {
        log("❌ SteppIR: TCPClient.connect(host:\(ipAddress), port:\(port)) failed")
        handleConnectionError()
    }
}

/// Disconnects from the SteppIR controller, stops polling, and resets connection state.
func disconnect() {
    log("🔌 SteppIR: Disconnecting")
    log("🛑 SteppIR: Teardown TCPClient and clear state")
    pollingTimer?.invalidate()
    pollingTimer = nil

    client?.disconnect()
    client?.onReceive = nil
    client = nil

    DispatchQueue.main.async {
        self.isConnected = false
    }
}

// MARK: – Private Helpers: Connection Error Handling

/// Called when the initial connection attempt fails.
/// Records an error message in `connectionError` and cleans up resources.
private func handleConnectionError() {
    log("❌ SteppIR: Connection failed to \(ipAddress):\(port)")
    pollingTimer?.invalidate()
    pollingTimer = nil

    client?.disconnect()
    client?.onReceive = nil
    client = nil

    DispatchQueue.main.async {
        self.connectionError = "Unable to reach SteppIR at \(self.ipAddress):\(self.port)"
    }
}

/// Called when the TCP client disconnects unexpectedly.
/// Sets `isConnected = false` and records a "Connection lost" error message.
private func handleDisconnect() {
    log("🔴 SteppIR: Connection lost")
    pollingTimer?.invalidate()
    pollingTimer = nil

    client = nil
    DispatchQueue.main.async {
        self.isConnected = false
        self.connectionError = "SteppIR connection lost"
    }
}

// MARK: – Private API: Polling

/// Sends a short status poll command (`?A\r`) to request current status from the SteppIR.
private func pollStatus() {
    log("SteppIR: Polling status...")
    let command: [UInt8] = [0x3F, 0x41, 0x0D] // "?A\r"
    client?.send(Data(command))
}

// MARK: – Private API: Incoming Data Handling

/// Called by `TCPClient` when raw data arrives.
/// Buffers data until a 0x0D terminator is detected, then processes each complete frame.
///
/// - Parameter data: The raw incoming `Data` chunk.
private func handleIncoming(data: Data) {
    if let incomingStr = String(data: data, encoding: .utf8) {
        log("📥 SteppIR: Raw incoming data chunk: '\(incomingStr)'")
    }
    log("SteppIR: Received \(data.count) bytes: \(data as NSData)")
    buffer.append(data)

    // Extract all complete frames up to the 0x0D terminator
    while let termIndex = buffer.firstIndex(of: 0x0D) {
        // Look for the SteppIR header 0x40 0x41 before the terminator
        if let headerIdx = buffer.firstIndex(of: 0x40),
           headerIdx + 1 < buffer.count,
           buffer[headerIdx + 1] == 0x41,
           headerIdx < termIndex {
            // Slice out exactly from 0x40 through 0x0D
            let fullFrame = buffer.subdata(in: headerIdx..<buffer.index(after: termIndex))
            processResponseSteppir(fullFrame)
        }
        // Drop everything up through the terminator, even if no valid header was found
        buffer.removeSubrange(0...termIndex)
    }
}

/// Parses a single complete frame from the SteppIR and updates published properties accordingly.
///
/// - Parameter data: The raw response `Data` including the terminator.
private func processResponseSteppir(_ data: Data) {
    log("🔍 SteppIR: Processing raw frame data: \(data as NSData)")
    let hexString = data.map { String(format: "%02X", $0) }.joined()
    log("SteppIR: Processing frame \(hexString)")

    guard let status = SteppIRStatus(from: hexString) else {
        log("⚠️ SteppIR: Ignoring non-matching or short frame. Data: \(hexString)")
        return
    }

    DispatchQueue.main.async {
        self.frequencyHz = status.frequencyHz
        self.tuningStatus = status.isTuning
        // Direction update logic with pendingDirection support
        if let pending = self.pendingDirection {
            if status.direction == pending {
                self.log("✅ SteppIR: Direction \(pending.rawValue) confirmed")
                self.pendingDirection = nil
                self.isManuallyChangingDirection = false
                self.direction = status.direction
            } else {
                self.log("⏳ Waiting for direction \(pending.rawValue) to take effect")
                return
            }
        } else {
            self.direction = status.direction
        }
        self.isTrackingEnabled = status.isTrackingEnabled

        self.log("SteppIR: Parsed frequency = \(status.frequencyHz) Hz")
        self.log("SteppIR: Tuning status = \(status.isTuning)")
        self.log("SteppIR: Direction = \(status.direction.rawValue)")
        self.log("SteppIR: Auto tracking is \(status.isTrackingEnabled ? "enabled" : "disabled")")
    }
}

// MARK: – Private Helpers: Data Conversion

/// Converts a hex string (e.g. "404100...") to a `Data` object.
///
/// - Parameter hex: The hex-encoded string.
/// - Returns: A `Data` object if parsing succeeds, or `nil` if any byte fails to parse.
private func hexStringToData(_ hex: String) -> Data? {
    var data = Data()
    var hex = hex
    while hex.count >= 2 {
        let byteString = String(hex.prefix(2))
        hex = String(hex.dropFirst(2))
        if let num = UInt8(byteString, radix: 16) {
            data.append(num)
        } else {
            return nil
        }
    }
    return data
}

/// Builds a command string given frequency, direction, and command.
private func buildCommand(freqHz: Int, direction: SteppIRDirection, command: SteppIRCommand) -> String {
    // Override freqHz to zero for enableTracking and disableTracking commands
    let adjustedFreqHz = (command == .enableTracking || command == .disableTracking) ? 0 : freqHz
    let freqHex = String(format: "%06X", adjustedFreqHz / 10)
    let idleMotorFlagsHex = "00"
    var packet = "404100" + freqHex + idleMotorFlagsHex
    switch direction {
    case .bidirectional: packet += "80"
    case .deg180:        packet += "40"
    case .normal:        packet += "00"
    }
    packet += String(format: "%02X", command.rawValue) + "000D"
    return packet
}

// MARK: – Private Helper: Send Frequency Update

/// Formats and sends a frequency update packet to the SteppIR controller.
/// - Parameter freqHz: Frequency in Hertz to send.
/// - Parameter overrideDirection: Optional direction to use instead of current state.
private func sendFrequencyUpdate(_ freqHz: Int, overrideDirection: SteppIRDirection? = nil) {
    if let pending = pendingDirection {
        if overrideDirection != pending {
            log("⏳ Skipping frequency update while direction change to \(pending.rawValue) is pending")
            return
        } else {
            log("🚀 Sending override frequency update for pending direction \(pending.rawValue)")
        }
    }

    let finalDir = overrideDirection ?? direction
    let command = buildCommand(freqHz: freqHz, direction: finalDir, command: .setFrequency)
    if let data = self.hexStringToData(command) {
        self.log("SteppIR: [DEBUG] Sending raw data: \(data as NSData)")
        client?.send(data)
    }
}

/// Public API: Request a user-driven direction change.
/// - Parameter newDirection: The desired SteppIRDirection.
func requestDirectionChange(_ newDirection: SteppIRDirection) {
    guard newDirection != direction else { return }
    log("🔁 User requested direction change to \(newDirection.rawValue)")
    pendingDirection = newDirection
    self.isManuallyChangingDirection = true
    sendFrequencyUpdate(k4Device.frequencyHz, overrideDirection: newDirection)
}

// MARK: – Public API: Control Commands

/// Sends a "Home" command to return the antenna to the home position.
func setHome() {
    let command = buildCommand(freqHz: 0, direction: direction, command: .home)
    log("SteppIR: Sending HOME command \(command)")
    if let data = hexStringToData(command) {
        self.log("SteppIR: [DEBUG] Sending HOME raw data: \(data as NSData)")
        client?.send(data)
    }
}

/// Sends an "Auto" command to enable or disable auto-tracking.
///
/// - Parameter enabled: Pass `true` to enable auto-tracking, `false` to disable.
func setAuto(enabled: Bool) {
    guard isConnected else {
        log("SteppIR: Not connected, skipping auto toggle")
        return
    }

    let cmd: SteppIRCommand = enabled ? .enableTracking : .disableTracking
    let command = buildCommand(freqHz: 0, direction: direction, command: cmd)  // force freq to 0 here

    log("SteppIR: Sending AUTO command \(command)")
    if let data = hexStringToData(command) {
        self.log("SteppIR: [DEBUG] Sending AUTO raw data: \(data as NSData)")
        client?.send(data)
    }

    DispatchQueue.main.async {
        self.isTrackingEnabled = enabled
    }

    if enabled, client != nil {
        // Slight delay to allow tracking state to settle on hardware
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.sendFrequencyUpdate(self.k4Device.frequencyHz)
        }
    }
}

/// Sends a "Calibrate" command to calibrate the SteppIR antenna.
func setCalibrate() {
    let command = buildCommand(freqHz: 0, direction: direction, command: .calibrate)
    log("SteppIR: Sending CALIBRATE command \(command)")
    if let data = hexStringToData(command) {
        self.log("SteppIR: [DEBUG] Sending CALIBRATE raw data: \(data as NSData)")
        client?.send(data)
    }
}
/// Parsed response model from SteppIR status message.
private struct SteppIRStatus {
let frequencyHz: Int
let isTuning: Bool
let direction: SteppIRDevice.SteppIRDirection
let isTrackingEnabled: Bool

init?(from hexString: String) {
    guard hexString.hasPrefix("4041"), hexString.count >= 22 else {
        return nil
    }

    // Parse frequency (next 6 hex chars after "4041")
    let freqHexStr = String(hexString.dropFirst(6).prefix(6))
    guard let freqRaw = Int(freqHexStr, radix: 16) else { return nil }
    frequencyHz = freqRaw / 100

    // Tuning byte is the 7th byte (after 6 bytes of frequency)
    let tuningByteStr = String(hexString.dropFirst(12).prefix(2))
    isTuning = (tuningByteStr != "00")

    // Direction byte is the next two chars
    let dirByteStr = String(hexString.dropFirst(14).prefix(2))
    let dirByte = UInt8(dirByteStr, radix: 16) ?? 0
    let dirBits = (dirByte & 0xE0) >> 5
    switch dirBits {
    case 0b000: direction = .normal
    case 0b010: direction = .deg180
    case 0b001, 0b100: direction = .bidirectional // handle both BID variants
    default: direction = .normal
    }

    isTrackingEnabled = (dirByte & 0x04) != 0
}
}
}
