//
//  ElecraftK4Device.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import Foundation
import Combine

class ElecraftK4Device: ObservableObject {
    @Published var frequencyHz: Int = 0
    @Published var currentFrequencyDisplay: String = ""
    @Published var isConnected: Bool = false

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
    private var client: TCPClient?
    private var pollingTimer: Timer?
    var buffer = Data()

    init(ipAddress: String = "192.168.1.10", port: Int = 9200) {
        self.ipAddress = ipAddress
        self.port = port
    }

    /// Establishes TCPClient connection and begins polling for FA updates
    func connect() {
        log("🚀 K4D: Starting connection to \(ipAddress):\(port)")
        client = TCPClient()
        client?.onReceive = handleIncoming(data:)
        client?.connect(host: ipAddress, port: UInt16(port))
        isConnected = true
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendCommand("FA;")
        }
        if let timer = pollingTimer {
            RunLoop.main.add(timer, forMode: .common)
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
}

extension ElecraftK4Device {
    /// Update IP address and port before connecting
    func updateConnectionDetails(ipAddress: String, port: Int) {
        self.ipAddress = ipAddress
        self.port = port
    }
}
