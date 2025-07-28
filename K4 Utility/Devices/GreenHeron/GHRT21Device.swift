//
//  GHRT21Device.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import Foundation
import Combine
import SwiftUI  // for SettingsStore access

/// Manages TCP/IP communication and polling for the Greenheron RT-21 rotator.
/// Publishes status updates and provides methods to send control commands.
@MainActor
class GHRT21Device: ObservableObject {
    // MARK: – Published Connection & Status Properties

    /// Indicates whether the TCP connection to the rotator is established.
    @Published var isConnected: Bool = false

    /// Holds the latest status string received from the rotator.
    @Published var status: String = ""

    /// Enables or disables debug logging (prints to console when true).
    @Published var debugEnabled: Bool = false

    /// Holds a human-readable error message if a connection or communication error occurs.
    @Published var connectionError: String?

    // MARK: – Networking Helpers

    /// Internal TCPClient instance handling socket communication.
    private var client: TCPClient?

    /// Buffer accumulating raw bytes until a complete semicolon-terminated frame is received.
    private var buffer = Data()

    /// Timer responsible for periodic polling of the rotator’s status.
    private var pollingTimer: Timer?

    // MARK: – Configuration & Persistence

    /// The rotator’s IP address, stored in `SettingsStore`.
    @Published var ipAddress: String = ""

    /// The rotator’s TCP port number, stored in `SettingsStore`.
    @Published var port: Int = 0

    /// Shared settings store for persisting IP, port, and preset configurations.
    private var settingsStore: SettingsStore

    /// Combine cancellables for persisting setting changes.
    private var cancellables = Set<AnyCancellable>()

    // MARK: – Dynamic Presets

    /// User-configurable array of azimuth values (0-359) for presets.
    @Published var presetAzimuths: [Int] = [0, 45, 90, 135, 180, 225, 270, 315]

    /// User-configurable array of preset names corresponding to `presetAzimuths`.
    @Published var presetNames: [String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

    // MARK: – Initialization

    /// Creates a new `GHRT21Device` using the provided `SettingsStore`.
    /// Loads saved IP, port, and presets from the store and sets up persistence.
    ///
    /// - Parameter settingsStore: Shared settings store containing `ghrt21` configurations.
    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore

        // Load saved IP address and port
        let saved = settingsStore.settings.ghrt21
        let deviceSettings = saved.device
        self.ipAddress = deviceSettings.ipAddress
        self.port = deviceSettings.port
        self.presetNames = saved.presetNames
        self.presetAzimuths = saved.presetAzimuths

        // Persist IP address changes back to SettingsStore
        $ipAddress
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.ghrt21.device.ipAddress = new
            }
            .store(in: &cancellables)

        // Persist port changes back to SettingsStore
        $port
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.ghrt21.device.port = new
            }
            .store(in: &cancellables)

        // Persist preset names
        $presetNames
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.ghrt21.presetNames = new
            }
            .store(in: &cancellables)

        // Persist preset azimuths
        $presetAzimuths
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.ghrt21.presetAzimuths = new
            }
            .store(in: &cancellables)
    }

    deinit {
        // Ensure a clean disconnect when the object is deallocated
        disconnect()
    }

    // MARK: – Public API: Connection Management

    /// Attempts to open a TCP connection to the rotator and starts polling with async support.
    func connect() {
        guard !isConnected else {
            log("⚠️ Connect called but already connected")
            return
        }
        
        log("🚀 Starting connection to \(ipAddress):\(port)")
        
        Task {
            await performConnection()
        }
    }
    
    /// Performs the actual connection attempt with retry logic
    @MainActor
    private func performConnection() async {
        do {
            client = TCPClient()
            client?.onReceive = { [weak self] data in
                self?.handleIncoming(data: data)
            }
            client?.onDisconnect = { [weak self] in
                DispatchQueue.main.async {
                    self?.handleDisconnect()
                }
            }
            
            let success = try await client?.connect(
                host: ipAddress,
                port: UInt16(port),
                timeout: 3.0,
                maxRetries: 1
            ) ?? false
            
            if success {
                log("✅ Connection successful")
                isConnected = true
                connectionError = nil
                
                // Start polling
                pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    Task { 
                        await self?.pollStatus()
                    }
                }
                if let timer = pollingTimer {
                    RunLoop.main.add(timer, forMode: .common)
                }
            } else {
                handleConnectionError()
            }
            
        } catch let error as TCPClient.TCPError {
            connectionError = error.localizedDescription
            log("❌ Connection failed: \(error.localizedDescription)")
        } catch {
            connectionError = "Unexpected error: \(error.localizedDescription)"
            log("❌ Connection failed: \(error.localizedDescription)")
        }
    }

    /// Disconnects from the rotator, stops polling, and resets connection state.
    nonisolated func disconnect() {
        log("🔌 GHRT21: Disconnecting")
        
        Task { @MainActor in
            pollingTimer?.invalidate()
            pollingTimer = nil
            
            client?.disconnect()
            client?.onReceive = nil
            client = nil
            
            isConnected = false
        }
    }

    // MARK: – Private Helpers: Connection Error Handling

    /// Called when the initial connection attempt fails.
    /// Records an error message in `connectionError` and cleans up resources.
    private func handleConnectionError() {
        log("❌ GHRT21: Connection failed to \(ipAddress):\(port)")
        pollingTimer?.invalidate()
        pollingTimer = nil

        client?.disconnect()
        client?.onReceive = nil
        client = nil

        DispatchQueue.main.async {
            self.connectionError = "Unable to reach device at \(self.ipAddress):\(self.port)"
        }
    }

    /// Called when the TCP client disconnects unexpectedly.
    /// Sets `isConnected = false` and records a "Connection lost" error message.
    private func handleDisconnect() {
        log("🔴 GHRT21: Connection lost")
        pollingTimer?.invalidate()
        pollingTimer = nil

        client = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionError = "Connection lost"
        }
    }

    // MARK: – Private API: Status Polling

    /// Sends the "AI;" command to request current status from the rotator.
    private func pollStatus() {
        let cmd = "AI;"
        log("🔄 GHRT21: Sending command \(cmd)")
        if let data = cmd.data(using: .ascii) {
            client?.send(data)
        }
    }

    // MARK: – Private API: Incoming Data Handling

    /// Called by `TCPClient` when raw data arrives.
    /// Buffers data until a semicolon-terminated frame is detected, then processes it.
    ///
    /// - Parameter data: The raw incoming `Data` chunk.
    private func handleIncoming(data: Data) {
        log("📡 GHRT21: Received \(data.count) bytes: \(data as NSData)")
        if let asciiChunk = String(data: data, encoding: .ascii) {
            log("🔤 GHRT21 ASCII chunk: \(asciiChunk)")
        }
        buffer.append(data)

        while let idx = buffer.firstIndex(of: UInt8(ascii: ";")) {
            let frameData = buffer.subdata(in: 0..<idx)
            log("🔍 GHRT21: Frame bytes: \(frameData as NSData)")
            if let asciiFrame = String(data: frameData, encoding: .ascii) {
                log("🔤 GHRT21 ASCII frame: \(asciiFrame)")
            }
            buffer.removeSubrange(0...idx)
            if let str = String(data: frameData, encoding: .ascii) {
                DispatchQueue.main.async {
                    self.processFrameString(str)
                }
            }
        }
    }

    /// Parses a single frame (without the semicolon) and updates the `status` property.
    ///
    /// - Parameter frame: The ASCII frame string received from the rotator.
    private func processFrameString(_ frame: String) {
        status = frame
        log("🔄 GHRT21: Received frame: \(frame)")
        // TODO: Extract and parse specific fields from `frame` as needed.
    }

    // MARK: – Public API: Control Commands

    /// Sends a "go to" command for the preset at the given index.
    ///
    /// - Parameter index: The index in `presetAzimuths` to move to.
    func goToPreset(at index: Int) {
        let heading = presetAzimuths[index]
        let work = String(format: "%03d", heading)
        let cmd = "AP0" + work + "\r;"
        log("🛰️ GHRT21: Sending preset command \(cmd)")
        if let data = cmd.data(using: .ascii) {
            client?.send(data)
        }
    }

    /// Sends a "stop motion" command to halt any ongoing movement.
    func stopMotion() {
        // Pause polling before sending stop command
        pollingTimer?.invalidate()
        pollingTimer = nil
        let cmd = "ST;"
        log("🛰️ GHRT21: Sending stop command \(cmd)")
        if let data = cmd.data(using: .ascii) {
            client?.send(data)
        }
        // Resume polling after a short delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            guard self.isConnected else { return }
            
            self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task {
                    await self?.pollStatus()
                }
            }
            if let timer = self.pollingTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    // MARK: – Public API: Arbitrary Azimuth Command

    /// Sends a "go to" command to move to the specified azimuth in degrees.
    ///
    /// - Parameter degrees: The azimuth in degrees (0–359) to move to.
    func goToAzimuth(degrees: Int) {
        let heading = degrees
        let work = String(format: "%03d", heading)
        let cmd = "AP0" + work + "\r;"
        log("🛰️ GHRT21: Sending goToAzimuth command \(cmd)")
        if let data = cmd.data(using: .ascii) {
            client?.send(data)
        }
    }

    // MARK: – Private Helpers

    /// Helper for conditional debug logging to the console.
    nonisolated private func log(_ message: String) {
        Task { @MainActor in
            if debugEnabled {
                print(message)
            }
        }
    }
}
