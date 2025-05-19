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

     var client: TCPClient?
     var ipAddress: String
     var port: Int
     var buffer = Data()

    init(ipAddress: String = "192.168.1.10", port: Int = 9200) {
        self.ipAddress = ipAddress
        self.port = port
    }

    func startConnection() {
        print("ElecraftK4Device: Starting connection to \(ipAddress):\(port)")
        client = TCPClient()
        client?.onReceive = { [weak self] data in
            self?.handleIncoming(data: data)
        }
        client?.connect(host: ipAddress, port: UInt16(port))
        isConnected = true

        // After a short delay, send initial commands
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendCommand("FA;")  // Query current frequency
            self.sendCommand("AI4;") // Enable auto info updates
        }
    }

    func stopConnection() {
        print("ElecraftK4Device: Disconnecting")
        client?.disconnect()
        isConnected = false
    }

    private func handleIncoming(data: Data) {
        guard String(data: data, encoding: .utf8) != nil else { return }
        buffer.append(data)
        let bufferStr = String(decoding: buffer, as: UTF8.self)
        let lines = bufferStr.components(separatedBy: ";")
        for line in lines.dropLast() { // drop last if partial
            if line.hasPrefix("FA") && line.count >= 12 {
                let freqStr = String(line.dropFirst(2))
                if let freq = Int(freqStr) {
                    DispatchQueue.main.async {
                        self.frequencyHz = freq
                        self.currentFrequencyDisplay = freqStr
                        print("ElecraftK4Device: Received FA frequency update: \(freq)")
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
        print("ElecraftK4Device: Sending command: \(command)")
        guard let data = (command + "\r").data(using: .utf8) else { return }
        client?.send(data)
    }
}

extension ElecraftK4Device {
    func connect() {
        startConnection()
    }

    func disconnect() {
        stopConnection()
    }

    func updateConnectionDetails(ipAddress: String, port: Int) {
        self.ipAddress = ipAddress
        self.port = port
    }
}
