//
//  GHRT21Device.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import Foundation
import Combine
import SwiftUI  // for SettingsStore access

/// Handles TCP/IP communication and polling for the GreenHeron RT-21 rotator
class GHRT21Device: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var status: String = ""
    @Published var debugEnabled: Bool = false
    @Published var connectionError: String?

    private var client: TCPClient?
    private var buffer = Data()
    private var pollingTimer: Timer?

    @Published var ipAddress: String = ""
    @Published var port: Int = 0
    private var settingsStore: SettingsStore
    private var cancellables = Set<AnyCancellable>()

    /// Helper for conditional logging
    private func log(_ message: String) {
        if debugEnabled {
            print("🛰️ GHRT21: \(message)")
        }
    }

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        // Load saved settings
        let saved = settingsStore.settings.ghrt21
        self.ipAddress = saved.device.ipAddress
        self.port = saved.device.port
        self.presetNames = saved.presetNames
        self.presetAzimuths = saved.presetAzimuths

        // Persist simple settings
        $ipAddress
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.ghrt21.device.ipAddress = new
            }
            .store(in: &cancellables)

        $port
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.ghrt21.device.port = new
            }
            .store(in: &cancellables)

        // Persist presets
        $presetNames
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.ghrt21.presetNames = new
            }
            .store(in: &cancellables)

        $presetAzimuths
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.ghrt21.presetAzimuths = new
            }
            .store(in: &cancellables)
    }

    /// Establishes TCPClient connection and starts polling
    func connect() {
        log("🔗 GHRT21: Attempting to connect to \(ipAddress):\(port)")
        client = TCPClient()
        client?.onReceive = handleIncoming(data:)
        client?.onDisconnect = handleDisconnect
        let success = client?.connect(host: ipAddress, port: UInt16(port)) ?? false
        if success {
            isConnected = true
            pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.pollStatus()
            }
            if let t = pollingTimer {
                RunLoop.main.add(t, forMode: .common)
            }
        } else {
            handleConnectionError()
        }
    }

    /// Disconnects and stops polling
    func disconnect() {
        log("🔌 GHRT21: Disconnecting")
        pollingTimer?.invalidate()
        pollingTimer = nil
        client?.disconnect()
        client?.onReceive = nil
        client = nil
        isConnected = false
    }

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

    /// Send the AI; command to request current status from the rotator
    private func pollStatus() {
        let cmd = "AI;"
        log("Sending command \(cmd)")
        if let data = cmd.data(using: .ascii) {
            client?.send(data)
        }
    }

    /// Handles raw incoming data, accumulating until semicolon terminator
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

    /// Parses a single frame (without the semicolon) and updates status
    private func processFrameString(_ frame: String) {
        status = frame
        log("Received frame: \(frame)")
        // TODO: parse fields out of `frame` as needed
    }


    // MARK: – Dynamic Presets
    
    /// User-configurable azimuth values for presets
    @Published var presetAzimuths: [Int] = [0, 45, 90, 135, 180, 225, 270, 315]
    
    /// User-configurable names for each preset
    @Published var presetNames: [String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

    /// Sends a “go to” command for a preset index
    func goToPreset(at index: Int) {
        let heading = presetAzimuths[index]
        let work = String(format: "%03d", heading)
        let cmd = "AP0" + work + "\r;"
        log("🛰️ GHRT21: Sending preset command \(cmd)")
        if let data = cmd.data(using: .ascii) {
            client?.send(data)
        }
    }

    /// Stop any ongoing relative motion
    func stopMotion() {
        let cmd = "ST;"
        log("🛰️ GHRT21: Sending stop command \(cmd)")
        if let data = cmd.data(using: .ascii) {
            client?.send(data)
        }
    }
}
