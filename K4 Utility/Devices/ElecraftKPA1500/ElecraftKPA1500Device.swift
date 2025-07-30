//
//  ElecraftKPA1500Device.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/20/25.
//

import Foundation
import Combine
import SwiftUI  // for SettingsStore access

/// Manages the TCP/IP connection and status polling for an Elecraft KPA-1500 amplifier.
/// Publishes operational metrics (power, temperature, SWR) and handles sending/receiving
/// amplifier-specific commands with automatic reconnection and proper error handling.
class ElecraftKPA1500Device: ObservableObject {
    // MARK: - Connection State Types
    
    enum DeviceConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case failed(String)
        
        var isConnectedBool: Bool {
            if case .connected = self { return true }
            return false
        }
        
        var displayText: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .reconnecting: return "Reconnecting..."
            case .failed(let message): return "Error: \(message)"
            }
        }
    }
    
    // MARK: – Published Connection & Status Properties

    /// User-defined button labels for macros (e.g., "ATU", "Reset", etc.)
    @Published var macroNames: [String] = Array(repeating: "", count: 3)

    /// Corresponding KPA1500 command strings (e.g., "^RS;", "^AT;", etc.)
    @Published var macroCommands: [String] = Array(repeating: "", count: 3)

    /// Indicates whether the TCP connection to the amplifier is currently open.
    @Published var isConnected: Bool = false
    
    /// Detailed connection state with better error information
    @Published var connectionState: DeviceConnectionState = .disconnected

    /// Holds a human-readable error message if a connection or communication error occurs.
    @Published var connectionError: String?

    /// The amplifier's set power output in watts.
    @Published var powerOutput: Double = 0

    /// The current amplifier temperature in degrees Celsius.
    /// Updates will log a debug message if `debugEnabled` is true.
    @Published var temperature: Double = 0 {
        didSet { log("🌡️ KPA1500: temperature changed to \(temperature) °C") }
    }

    /// The current selected band (e.g., "20m", "40m", etc.).
    @Published var currentBand: String = ""

    /// The current amplifier mode ("Operate" or "Standby").
    @Published var operateMode: String = ""

    /// Whether the internal tuner is in-line (true) or bypassed (false).
    @Published var isInline: Bool = false

    /// The currently selected antenna port number.
    @Published var antennaPort: Int = 0

    /// The forward power reading in watts.
    /// Updates log a debug message with the new forward power.
    @Published var forwardPower: Double = 0 {
        didSet { log("📈 KPA1500: forwardPower changed to \(forwardPower) W") }
    }

    /// The reflected power reading in watts.
    /// Updates log a debug message with the new reflected power.
    @Published var reflectedPower: Double = 0 {
        didSet { log("📉 KPA1500: reflectedPower changed to \(reflectedPower) W") }
    }

    /// The amplifier's input power reading in watts.
    /// Updates log a debug message with the new input power.
    @Published var inputPower: Double = 0 {
        didSet { log("🔌 KPA1500: inputPower changed to \(inputPower) W") }
    }

    /// The current standing wave ratio (SWR), scaled (e.g., 1.2).
    /// Updates log a debug message with the new SWR.
    @Published var swr: Double = 0 {
        didSet { log("📏 KPA1500: SWR changed to \(swr)") }
    }

    /// The amplifier's plate voltage in volts.
    /// Updates log a debug message with the new plate voltage.
    @Published var paVoltage: Double = 0 {
        didSet { log("🔌 KPA1500: paVoltage changed to \(paVoltage) V") }
    }

    /// The amplifier's plate current in amperes.
    /// Updates log a debug message with the new plate current.
    @Published var paCurrent: Double = 0 {
        didSet { log("🔌 KPA1500: paCurrent changed to \(paCurrent) A") }
    }

    /// If true, debug logging (print statements) is enabled.
    @Published var debugEnabled: Bool = false {
        didSet {
            if debugEnabled {
                TCPClient.enableDebug()
            } else {
                TCPClient.disableDebug()
            }
        }
    }

    // MARK: – Networking Properties

    /// The TCP client used for amplifier communication.
    private var client: TCPClient?

    /// A buffer accumulating raw incoming bytes until complete frames are parsed.
    private var buffer = Data()

    /// A timer that triggers periodic status polling.
    private var pollingTimer: Timer?
    
    /// Reconnection management
    private var reconnectionTimer: Timer?
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 2

    // MARK: – Configuration & Persistence

    /// The IP address for the amplifier connection, stored in SettingsStore.
    @Published var ipAddress: String = ""

    /// The port number for the amplifier connection, stored in SettingsStore.
    @Published var port: Int = 0

    /// Shared settings store for persisting IP/port changes.
    private var settingsStore: SettingsStore

    /// Combine cancellables for persisting settings.
    private var cancellables = Set<AnyCancellable>()

    // MARK: – Initialization

    /// Creates a new `ElecraftKPA1500Device` using the provided `SettingsStore`.
    /// Loads saved IP and port from the store and hooks up persistence.
    ///
    /// - Parameter settingsStore: A shared settings store containing `kpa1500` settings.
    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore

        // Load saved settings from SettingsStore
        let saved = settingsStore.settings.kpa1500.device
        self.ipAddress = saved.ipAddress
        self.port = saved.port

        // Load user-defined macro labels and commands
        self.macroNames = settingsStore.settings.kpa1500Macros.macroNames
        self.macroCommands = settingsStore.settings.kpa1500Macros.macroCommands

        setupSettingsPersistence()
        setupConnectionStateObservation()
    }

    deinit {
        // Ensure the connection is closed if the object is deallocated
        disconnect()
    }
    
    // MARK: - Settings Persistence
    
    private func setupSettingsPersistence() {
        // Persist IP address changes back into SettingsStore
        $ipAddress
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.kpa1500.device.ipAddress = new
            }
            .store(in: &cancellables)

        // Persist port changes back into SettingsStore
        $port
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.kpa1500.device.port = new
            }
            .store(in: &cancellables)

        // Persist macroNames back into SettingsStore on change
        $macroNames
            .dropFirst()
            .sink { [weak self] newNames in
                self?.settingsStore.settings.kpa1500Macros.macroNames = newNames
            }
            .store(in: &cancellables)

        // Persist macroCommands back into SettingsStore on change
        $macroCommands
            .dropFirst()
            .sink { [weak self] newCommands in
                self?.settingsStore.settings.kpa1500Macros.macroCommands = newCommands
            }
            .store(in: &cancellables)
    }
    
    private func setupConnectionStateObservation() {
        // Update legacy isConnected property when connection state changes
        $connectionState
            .map { $0.isConnectedBool }
            .assign(to: &$isConnected)
        
        // Update error message when connection fails
        $connectionState
            .sink { [weak self] state in
                if case .failed(let message) = state {
                    self?.connectionError = message
                } else if state.isConnectedBool {
                    self?.connectionError = nil
                }
            }
            .store(in: &cancellables)
    }

    // MARK: – Public API: Connection Management

    /// Attempts to open a TCP connection to the Elecraft KPA-1500 amplifier.
    func connect() {
        guard connectionState != .connecting && connectionState != .connected else {
            log("⚠️ Connect called but already connecting/connected")
            return
        }
        
        // Cancel any existing reconnection timer and reset state for manual connection
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        
        log("🚀 Starting connection to \(ipAddress):\(port)")
        connectionState = .connecting
        reconnectionAttempts = 0
        
        Task {
            await performConnection()
        }
    }
    
    /// Performs the actual connection attempt with retry logic
    @MainActor
    private func performConnection() async {
        do {
            // Ensure any existing client is fully disconnected
            client?.disconnect()
            client = nil
            
            client = TCPClient()
            setupTCPClientCallbacks()
            
            let success = try await client?.connect(
                host: ipAddress,
                port: UInt16(port),
                timeout: 3.0,
                maxRetries: 1
            ) ?? false
            
            if success {
                log("✅ Connection successful")
                connectionState = .connected
                reconnectionAttempts = 0
                
                // Start polling
                startPollingTimer()
            } else {
                handleConnectionFailure("Connection failed")
            }
            
        } catch let error as TCPClient.TCPError {
            handleConnectionFailure(error.localizedDescription)
        } catch {
            handleConnectionFailure("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    /// Sets up TCP client callback handlers with proper memory management
    private func setupTCPClientCallbacks() {
        client?.onReceive = { [weak self] data in
            self?.handleIncoming(data: data)
        }
        
        client?.onDisconnect = { [weak self] in
            DispatchQueue.main.async {
                self?.handleUnexpectedDisconnection()
            }
        }
        
        client?.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleTCPStateChange(state)
            }
        }
    }
    
    /// Handles TCP client state changes for better connection feedback
    private func handleTCPStateChange(_ state: TCPClient.ConnectionState) {
        switch state {
        case .connecting:
            if connectionState != .connecting {
                connectionState = .connecting
            }
        case .connected:
            // Handled in performConnection
            break
        case .disconnected:
            if connectionState == .connected || connectionState == .reconnecting {
                handleUnexpectedDisconnection()
            }
        case .failed(let error):
            handleConnectionFailure(error.localizedDescription)
        }
    }

    /// Disconnects from the amplifier, invalidates polling, and resets connection state.
    func disconnect() {
        log("🔌 KPA1500: Disconnecting")
        
        stopPollingTimer()
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil

        client?.disconnect()
        client = nil

        connectionState = .disconnected
    }

    // MARK: – Private Helpers: Connection Error Handling
    
    /// Handles connection failures with user-friendly error messages
    private func handleConnectionFailure(_ message: String) {
        log("❌ Connection failed: \(message)")
        stopPollingTimer()
        
        client?.disconnect()
        client = nil
        
        connectionState = .failed(message)
        
        // Schedule reconnection if this wasn't a manual disconnect
        if reconnectionAttempts < maxReconnectionAttempts {
            scheduleReconnection()
        }
    }
    
    /// Handles unexpected disconnections and attempts reconnection
    private func handleUnexpectedDisconnection() {
        guard connectionState.isConnectedBool || connectionState == .reconnecting else {
            return // Don't reconnect if we manually disconnected
        }
        
        log("🔴 Connection lost unexpectedly")
        stopPollingTimer()
        client = nil
        
        if reconnectionAttempts < maxReconnectionAttempts {
            scheduleReconnection()
        } else {
            connectionState = .failed("Connection lost. Maximum reconnection attempts exceeded.")
        }
    }
    
    /// Schedules automatic reconnection with progressive backoff
    private func scheduleReconnection() {
        reconnectionAttempts += 1
        let delay = min(3.0 + Double(reconnectionAttempts * 2), 15.0) // Start at 5s, increase by 2s, cap at 15s
        
        log("🔄 Scheduling reconnection attempt \(reconnectionAttempts) in \(delay)s")
        connectionState = .reconnecting
        
        reconnectionTimer?.invalidate()
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.connectionState == .reconnecting {
                Task {
                    await self.performConnection()
                }
            }
        }
    }

    // MARK: – Private API: Status Polling
    
    /// Starts the polling timer for periodic status updates
    private func startPollingTimer() {
        stopPollingTimer()
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self, self.connectionState.isConnectedBool else { return }
            self.pollStatus()
        }
        
        if let timer = pollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// Stops the polling timer
    private func stopPollingTimer() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    /// Sends a series of status query commands to the amplifier.
    /// Each command ends with a carriage return and is defined by the KPA-1500 protocol.
    private func pollStatus() {
        let commands = ["^BN;", "^OS;", "^AI;", "^AP;", "^PWF;", "^PWI;", "^PWR;", "^SW;", "^VI;", "^TM;"]
        for cmd in commands {
            let fullCmd = cmd + "\r"
            log("🔄 KPA1500: Sending command \(cmd)")
            if let data = fullCmd.data(using: .ascii) {
                client?.send(data)
            }
        }
    }

    // MARK: – Private API: Incoming Data Handling

    /// Called by `TCPClient` when raw data arrives.
    /// Buffers data until semicolon-terminated frames are detected, then sends each to `processFrameString(_:)`.
    ///
    /// - Parameter data: The raw incoming `Data` chunk.
    private func handleIncoming(data: Data) {
        buffer.append(data)
        while let idx = buffer.firstIndex(of: UInt8(ascii: ";")) {
            let frameData = buffer.subdata(in: 0..<idx)
            buffer.removeSubrange(0...idx)
            if let str = String(data: frameData, encoding: .ascii) {
                DispatchQueue.main.async {
                    self.log("📥 KPA1500: Received frame: \(str)")
                    self.processFrameString(str)
                }
            }
        }
    }

    /// Parses a single semicolon-terminated frame string and updates published properties accordingly.
    ///
    /// - Parameter frame: A string such as "^PWF123.4", where the prefix indicates the frame type.
    private func processFrameString(_ frame: String) {
        DispatchQueue.main.async {
            switch true {
            case frame.hasPrefix("^BN"):
                // Band number mapping
                let code = frame.dropFirst(3)
                switch code {
                case "00": self.currentBand = "160m"
                case "01": self.currentBand = "80m"
                case "02": self.currentBand = "60m"
                case "03": self.currentBand = "40m"
                case "04": self.currentBand = "30m"
                case "05": self.currentBand = "20m"
                case "06": self.currentBand = "17m"
                case "07": self.currentBand = "15m"
                case "08": self.currentBand = "12m"
                case "09": self.currentBand = "10m"
                case "10": self.currentBand = "6m"
                default: break
                }
                self.log("🔢 KPA1500: Band = \(self.currentBand)")

            case frame.hasPrefix("^OS"):
                // Operate/Standby flag
                let code = frame.dropFirst(3)
                self.operateMode = (code == "1") ? "Operate" : "Standby"
                self.log("🟢 KPA1500: Mode = \(self.operateMode)")

            case frame.hasPrefix("^AI"):
                // Tuner inline status
                self.isInline = (frame.dropFirst(3) == "1")
                self.log("🏷️ KPA1500: Tuner Inline = \(self.isInline)")

            case frame.hasPrefix("^AP"):
                // Antenna port number
                if let num = Int(frame.dropFirst(3)) {
                    self.antennaPort = num
                }
                self.log("📡 KPA1500: Antenna Port = \(self.antennaPort)")

            case frame.hasPrefix("^PWF"):
                // Forward power
                if let val = Double(frame.dropFirst(4)) {
                    self.forwardPower = val
                }
                self.log("📈 KPA1500: Forward Power = \(self.forwardPower) W")

            case frame.hasPrefix("^PWI"):
                // Input power
                if let val = Double(frame.dropFirst(4)) {
                    self.inputPower = val
                }
                self.log("🔌 KPA1500: Input Power = \(self.inputPower) W")

            case frame.hasPrefix("^PWR"):
                // Reflected power
                if let val = Double(frame.dropFirst(4)) {
                    self.reflectedPower = val
                }
                self.log("📉 KPA1500: Reflected Power = \(self.reflectedPower) W")

            case frame.hasPrefix("^SW"):
                // SWR reading (tenths)
                if let val = Double(frame.dropFirst(3)) {
                    self.swr = val / 10.0
                }
                self.log("📏 KPA1500: SWR = \(self.swr)")

            case frame.hasPrefix("^VI"):
                // Voltage and current (e.g. "VI123.4 56.7")
                let body = frame.dropFirst(3)
                let parts = body.split(separator: " ")
                if parts.count >= 2,
                   let v = Double(parts[0]),
                   let c = Double(parts[1]) {
                    self.paVoltage = v
                    self.paCurrent = c
                }
                self.log("⚡ KPA1500: Voltage = \(self.paVoltage)V, Current = \(self.paCurrent)A")

            case frame.hasPrefix("^TM"):
                // Temperature reading
                if let val = Double(frame.dropFirst(3)) {
                    self.temperature = val
                }
                self.log("🌡️ KPA1500: Temperature = \(self.temperature)°C")

            default:
                break
            }
        }
    }

    // MARK: – Public API: Control Commands

    /// Sends a command to set the amplifier to Operate (true) or Standby (false) mode.
    ///
    /// - Parameter enabled: Pass `true` to enter Operate mode, `false` for Standby.
    func setOperateMode(_ enabled: Bool) {
        guard connectionState.isConnectedBool else {
            log("⚠️ KPA1500: Cannot send command - not connected")
            return
        }
        
        let code = enabled ? "1" : "0"
        let cmd = "^OS\(code);"
        let fullCmd = cmd + "\r"
        log("🔄 KPA1500: Sending Mode command \(cmd)")
        if let data = fullCmd.data(using: .ascii) {
            client?.send(data)
        }
    }

    /// Sends a raw command string to the amplifier (macro or manual).
    ///
    /// - Parameter command: The full command string (e.g., "^RS;", "^AT;").
    public func sendCommand(_ command: String) {
        guard connectionState.isConnectedBool else {
            log("⚠️ KPA1500: Cannot send command - not connected")
            return
        }
        
        log("📤 KPA1500: Sending command: \(command)")
        let fullCmd = command + "\r"
        if let data = fullCmd.data(using: .ascii) {
            client?.send(data)
        }
    }
    
    /// Returns the macro label at a given index, or a fallback label if unavailable.
    public func macroLabel(at index: Int) -> String {
        guard index >= 0 && index < macroNames.count else {
            return "Macro \(index + 1)"
        }
        return macroNames[index].isEmpty ? "Macro \(index + 1)" : macroNames[index]
    }
    
    // MARK: – Private Helpers

    /// Prints a debug message when `debugEnabled` is true.
    ///
    /// - Parameter message: The debug string to print.
    private func log(_ message: String) {
        if debugEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] \(message)")
        }
    }
}
