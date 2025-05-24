//
//  ElecraftK4Device.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import Foundation
import Combine
import Network

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

    private func log(_ message: String) {
        if debugEnabled {
            print(message)
        }
    }

     private var connection: NWConnection?
     private var pollingTimer: Timer?
     var ipAddress: String
     var port: Int
     var buffer = Data()

    init(ipAddress: String = "192.168.1.10", port: Int = 9200) {
        self.ipAddress = ipAddress
        self.port = port
    }

    func startConnection() {
        log("🚀 K4D: Starting connection to \(ipAddress):\(port)")
        let host = NWEndpoint.Host(ipAddress)
        let nwPort = NWEndpoint.Port(rawValue: UInt16(port))!
        let params = NWParameters.tcp
        let conn = NWConnection(host: host, port: nwPort, using: params)
        self.connection = conn
        
        conn.stateUpdateHandler = { [weak self] newState in
            DispatchQueue.main.async {
                switch newState {
                case .ready:
                    self?.isConnected = true
                    self?.log("✅ K4D: Connection ready")
                    self?.startReceiveLoop()
                    // Begin polling frequency
                    self?.sendCommand("FA;")
                    self?.pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                        self?.sendCommand("FA;")
                    }
                    if let t = self?.pollingTimer {
                        RunLoop.main.add(t, forMode: .common)
                    }
                case .failed(let error):
                    self?.isConnected = false
                    self?.log("❌ K4D: Connection failed – \(error.localizedDescription)")
                case .cancelled:
                    self?.isConnected = false
                    self?.log("🔌 K4D: Connection cancelled")
                default:
                    break
                }
            }
        }
        conn.start(queue: .main)
    }

    func stopConnection() {
        log("🔌 K4D: Disconnecting")
        pollingTimer?.invalidate()
        pollingTimer = nil
        connection?.cancel()
        connection = nil
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

    /// Continuously receive data until connection is closed
    private func startReceiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleIncoming(data: data)
            }
            if error == nil && !isComplete {
                self?.startReceiveLoop()
            }
        }
    }

    func sendCommand(_ command: String) {
        log("📤 K4D: Sending command: \(command)")
        guard let data = (command + "\r").data(using: .utf8) else { return }
        connection?.send(content: data, completion: .contentProcessed { _ in })
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
