//
//  ElecraftK4Device.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import Foundation
import Combine
import SwiftUI  // for accessing SettingsStore

class ElecraftK4Device: ObservableObject {
    @Published var frequencyHz: Int = 0
    @Published var currentFrequencyDisplay: String = ""
    @Published var isConnected: Bool = false
    @Published var connectionError: String?

    @Published var debugEnabled: Bool = false {
        didSet {
            if debugEnabled {
                TCPClient.enableDebug()
            } else {
                TCPClient.disableDebug()
            }
        }
    }

    @Published var ipAddress: String = "192.168.1.10"
    @Published var port: Int = 9200
    private var settingsStore: SettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var client: TCPClient?
    private var pollingTimer: Timer?
    var buffer = Data()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        // Load saved settings
        let saved = settingsStore.settings.k4
        self.ipAddress = saved.ipAddress
        self.port = saved.port

        // Persist changes to settings
        $ipAddress
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.k4.ipAddress = new
            }
            .store(in: &cancellables)

        $port
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.k4.port = new
            }
            .store(in: &cancellables)
    }

    /// Establishes TCPClient connection and begins polling for FA updates
    func connect() {
        log("🚀 K4D: Starting connection to \(ipAddress):\(port)")
        client = TCPClient()
        client?.onReceive = handleIncoming(data:)
        client?.onDisconnect = handleDisconnect
        let success = client?.connect(host: ipAddress, port: UInt16(port)) ?? false
        if success {
            isConnected = true
            pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.sendCommand("FA;")
            }
            if let timer = pollingTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        } else {
            handleConnectionError()
        }
    }

    /// Stops polling and disconnects the TCPClient
    func disconnect() {
        log("🔌 K4D: Disconnecting")
        pollingTimer?.invalidate()
        pollingTimer = nil
        client?.disconnect()
        client?.onReceive = nil
        client = nil
        isConnected = false
    }

    private func handleIncoming(data: Data) {
        guard String(data: data, encoding: .utf8) != nil else { return }
        buffer.append(data)
        let bufferStr = String(decoding: buffer, as: UTF8.self)
        let lines = bufferStr.components(separatedBy: ";")
        for line in lines.dropLast() { // drop last if partial
            if line.hasPrefix("FA") {
                let freqStr = String(line.dropFirst(2))
                if let freq = Int(freqStr) {
                    DispatchQueue.main.async {
                        self.frequencyHz = freq
                        self.currentFrequencyDisplay = freqStr
                        self.log("📥 K4D: Received FA frequency update: \(freq)")
                    }
                }
            }
        }
        // Keep any partial message in buffer
        if let lastSemi = buffer.lastIndex(of: UInt8(ascii: ";")) {
            buffer.removeSubrange(0...lastSemi)
        }
    }

    func sendCommand(_ command: String) {
        log("📤 K4D: Sending command: \(command)")
        guard let data = (command + "\r").data(using: .utf8) else { return }
        client?.send(data)
    }

    private func log(_ message: String) {
        if debugEnabled {
            print(message)
        }
    }

    private func handleConnectionError() {
        log("❌ K4D: Connection failed to \(ipAddress):\(port)")
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

