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
    // MARK: – Published Properties (State)

    /// The current frequency in Hertz to set on the SteppIR controller.
    @Published var frequencyHz: Int = 0

    /// The current direction mode ("Normal", "180", "BID", "34").
    @Published var direction: String = "Normal"

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

    /// Prints a debug message when `debugEnabled` is true.
    ///
    /// - Parameter message: The debug message to print.
    private func log(_ message: String) {
        if debugEnabled {
            print(message)
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
        let saved = settingsStore.settings.steppIR
        self.ipAddress = saved.ipAddress
        self.port = saved.port

        // Persist IP address changes back to SettingsStore
        $ipAddress
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.steppIR.ipAddress = new
            }
            .store(in: &cancellables)

        // Persist port changes back to SettingsStore
        $port
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.steppIR.port = new
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
                self.sendFrequencyUpdate(k4.frequencyHz)
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
        client?.onReceive = handleIncoming(data:)
        client?.onDisconnect = handleDisconnect

        let success = client?.connect(host: ipAddress, port: UInt16(port)) ?? false
        if success {
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
            handleConnectionError()
        }
    }

    /// Disconnects from the SteppIR controller, stops polling, and resets connection state.
    func disconnect() {
        log("🔌 SteppIR: Disconnecting")
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
        log("SteppIR: Received \(data.count) bytes: \(data as NSData)")
        buffer.append(data)

        while let terminatorRange = buffer.range(of: Data([0x0D])) {
            let frame = buffer.subdata(in: 0..<terminatorRange.upperBound)
            buffer.removeSubrange(0..<terminatorRange.upperBound)
            processResponseSteppir(frame)
        }
    }

    /// Parses a single complete frame from the SteppIR and updates published properties accordingly.
    ///
    /// - Parameter data: The raw response `Data` including the terminator.
    private func processResponseSteppir(_ data: Data) {
        let hexString = data.map { String(format: "%02X", $0) }.joined()
        log("SteppIR: Processing frame \(hexString)")

        guard hexString.hasPrefix("4041"), hexString.count >= 20 else {
            log("SteppIR: Ignoring non-matching or short frame.")
            return
        }

        DispatchQueue.main.async {
            // Update frequency: next 6 hex digits after "4041" -> divide by 100
            if let freqHex = Int(hexString.dropFirst(6).prefix(6), radix: 16) {
                self.frequencyHz = freqHex / 100
                self.log("SteppIR: Parsed frequency = \(self.frequencyHz) Hz")
            }

            // Tuning status: byte at index 6+6..8 hex digits (two chars)
            let tuningByte = hexString.dropFirst(12).prefix(2)
            self.tuningStatus = (tuningByte != "00")
            self.log("SteppIR: Tuning status = \(self.tuningStatus)")

            // Direction bits: next two hex digits -> top 3 bits for direction
            let dirBits = (Int(hexString.dropFirst(14).prefix(2), radix: 16) ?? 0) & 0xE0
            switch dirBits >> 5 {
            case 0: self.direction = "Normal"
            case 2: self.direction = "180"
            case 4: self.direction = "BID"
            default: self.direction = "Normal"
            }
            self.log("SteppIR: Direction = \(self.direction)")
        }

        // Auto-tracking bit: third bit of the same direction byte
        let trackByteHex = hexString.dropFirst(14).prefix(2)
        if let trackByte = UInt8(trackByteHex, radix: 16) {
            let isAuto = (trackByte & 0x04) >> 2
            DispatchQueue.main.async {
                self.isTrackingEnabled = (isAuto == 1)
                self.log("SteppIR: Auto tracking is \(self.isTrackingEnabled ? "enabled" : "disabled")")
            }
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
    
    // MARK: – Private Helper: Send Frequency Update
    
    /// Formats and sends a frequency update packet to the SteppIR controller.
    /// - Parameter freqHz: Frequency in Hertz to send.
    private func sendFrequencyUpdate(_ freqHz: Int) {
        let tenHzUnits = freqHz / 10
        let hexFreq = String(format: "%06X", tenHzUnits & 0xFFFFFF)
        var packet = "404100" + hexFreq + "00"
        switch self.direction.uppercased() {
        case "BID":
            packet += "80"
        case "180":
            packet += "40"
        default:
            packet += "00"
        }
        // Append auto‐bit = 0x52 (keep tracking enabled) and terminator
        packet += "52" + "000D"
        if let data = self.hexStringToData(packet) {
            self.log("SteppIR: [DEBUG] Sending raw data: \(data as NSData)")
            client?.send(data)
        }
    }

    // MARK: – Public API: Control Commands

    /// Sends a "Home" command to return the antenna to the home position.
    func setHome() {
        let hexFreq = String(format: "%06X", frequencyHz * 100)
        var command = "404140" + hexFreq + "00"
        switch direction.uppercased() {
        case "BID": command += "80"
        case "180": command += "40"
        default: command += "00"
        }
        command += "53000D"
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

        let hexFreq = String(format: "%06X", frequencyHz * 100)
        var command = "404100" + hexFreq + "00"
        switch direction.uppercased() {
        case "BID": command += "80"
        case "180": command += "40"
        default: command += "00"
        }
        let toggleCode = enabled ? "52" : "55"
        command += toggleCode + "000D"
        log("SteppIR: Sending AUTO command \(command)")
        if let data = hexStringToData(command) {
            self.log("SteppIR: [DEBUG] Sending AUTO raw data: \(data as NSData)")
            client?.send(data)
        }
        DispatchQueue.main.async {
            self.isTrackingEnabled = enabled
        }
        if enabled, client != nil {
            sendFrequencyUpdate(k4Device.frequencyHz)
        }
    }

    /// Sends a "Calibrate" command to calibrate the SteppIR antenna.
    func setCalibrate() {
        let hexFreq = String(format: "%06X", frequencyHz * 100)
        var command = "404140" + hexFreq + "00"
        switch direction.uppercased() {
        case "BID": command += "80"
        case "180": command += "40"
        default: command += "00"
        }
        command += "56000D"
        log("SteppIR: Sending CALIBRATE command \(command)")
        if let data = hexStringToData(command) {
            self.log("SteppIR: [DEBUG] Sending CALIBRATE raw data: \(data as NSData)")
            client?.send(data)
        }
    }
}
