//
//  ElecraftKPA1500Device.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/20/25.
//

// ElecraftKPA1500Device.swift
// Handles TCP/IP communication and publishes metrics
import Foundation
import Combine

class ElecraftKPA1500Device: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var powerOutput: Double = 0  // e.g., in watts
    @Published var temperature: Double = 0  // e.g., in °C

    private var client: TCPClient?
    private var buffer = Data()
    private var pollingTimer: Timer?

    var ipAddress: String = "192.168.1.9"
    var port: Int = 1500

    func connect() {
        client = TCPClient()
        client?.onReceive = handleIncoming(data:)
        client?.connect(host: ipAddress, port: UInt16(port))
        isConnected = true
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollStatus()
        }
        if let t = pollingTimer { RunLoop.main.add(t, forMode: .common) }
    }

    func disconnect() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        client?.disconnect()
        client?.onReceive = nil
        client = nil
        isConnected = false
    }

    private func pollStatus() {
        // Example command to request status; replace with real protocol
        let cmd: [UInt8] = [0x3F, 0x50, 0x0D]
        client?.send(Data(cmd))
    }

    private func handleIncoming(data: Data) {
        buffer.append(data)
        // parse full frames terminated by 0x0D
        while let idx = buffer.firstIndex(of: 0x0D) {
            let frame = buffer.subdata(in: 0..<idx)
            buffer.removeSubrange(0...idx)
            processFrame(frame)
        }
    }

    private func processFrame(_ data: Data) {
        let hex = data.map { String(format: "%02X", $0) }.joined()
        // TODO: parse hex string into powerOutput and temperature
        DispatchQueue.main.async {
            // stub parsing:
            self.powerOutput = Double.random(in: 0...1500)
            self.temperature = Double.random(in: 20...80)
        }
    }
}

