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
    @Published var ipAddress: String
    @Published var port: Int
    @Published var forwardPower: Double = 0
    @Published var reflectedPower: Double = 0
    @Published var swr: Double = 1.0

    @Published var debugEnabled: Bool = false {
        didSet {
            if debugEnabled {
                TCPClient.enableDebug()
            } else {
                TCPClient.disableDebug()
            }
        }
    }

 
    private var settingsStore: SettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var client: TCPClient?
    private var pollingTimer: Timer?
    var buffer = Data()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        
        // Initialize address and port from settings
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
            // Send initial info commands once
            self.sendCommand("FA;")
            self.sendCommand("AI5;")
            self.sendCommand("TM1;")
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
            else if line.hasPrefix("TM") {
                // TM aaabbbcccddd; either comma-separated or fixed-width
                let body = line.dropFirst(2)
                if body.contains(",") {
                    // comma-separated: fwd,ref,alckey,swr,...
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
                } else if body.count >= 12 {
                    // fixed-width: aaa (ALC), bbb (CMP), ccc (FWD), ddd (SWR)
                    let str = String(body)
                    let fwdStr = String(str[str.index(str.startIndex, offsetBy: 6)..<str.index(str.startIndex, offsetBy: 9)])
                    let refStr = String(str[str.index(str.startIndex, offsetBy: 3)..<str.index(str.startIndex, offsetBy: 6)])
                    let swrStr = String(str[str.index(str.startIndex, offsetBy: 9)..<str.index(str.startIndex, offsetBy: 12)])
                    if let fwd = Double(fwdStr), let ref = Double(refStr), let swrTenths = Double(swrStr) {
                        DispatchQueue.main.async {
                            self.forwardPower = fwd
                            self.reflectedPower = ref
                            self.swr = swrTenths / 10.0
                        }
                    }
                }
            }
            else if line.hasPrefix("PO") {
                // POwwww
                let value = line.dropFirst(2).dropLast()
                if let total = Double(value) {
                    DispatchQueue.main.async {
                        // total transmit power; re-use forwardPower or store separately if needed
                        self.forwardPower = total
                    }
                }
            }
            else if line.hasPrefix("SW") {
                // SWsss
                let value = line.dropFirst(2).dropLast()
                if let tenths = Double(value) {
                    DispatchQueue.main.async {
                        self.swr = tenths / 10.0
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
