//
//  SteppIRDevice.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import Foundation
import Combine
import Network

class SteppIRDevice: ObservableObject {
    @Published var frequencyHz: Int = 0
    @Published var direction: String = "Normal"
    @Published var isTrackingEnabled: Bool = false
    @Published var isConnected: Bool = false
    @Published var tuningStatus: Bool = false
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
    private var buffer = Data()

    var ipAddress: String
    var port: Int
    private var pollingTimer: Timer?

    init(ipAddress: String = "192.168.1.18", port: Int = 10001) {
        self.ipAddress = ipAddress
        self.port = port
    }

    func connect() {
        log("🔗 SteppIR: Attempting to connect to \(ipAddress):\(port)")
        // Create and start NWConnection
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
                    self?.log("✅ SteppIR: Connection ready")
                    self?.startReceiveLoop()
                    // Start polling status on successful connect
                    self?.pollingTimer?.invalidate()
                    self?.pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                        self?.pollStatus()
                    }
                    if let t = self?.pollingTimer {
                        RunLoop.main.add(t, forMode: .common)
                    }
                case .waiting(let error):
                    self?.isConnected = false
                    self?.log("⏳ SteppIR: Waiting to connect – \(error.localizedDescription)")
                case .failed(let error):
                    self?.isConnected = false
                    self?.log("❌ SteppIR: Connection failed – \(error.localizedDescription)")
                case .cancelled:
                    self?.isConnected = false
                    self?.log("🔌 SteppIR: Connection cancelled")
                default:
                    break
                }
            }
        }
        conn.start(queue: .main)
    }

    func disconnect() {
        log("🔌 SteppIR: Disconnecting")
        pollingTimer?.invalidate()
        pollingTimer = nil
        connection?.cancel()
        connection = nil
        isConnected = false
    }

    func setFrequency(_ freq: Int) {
        frequencyHz = freq
        sendFrequencyUpdate()
    }

    func setDirection(_ newDirection: String) {
        direction = newDirection
        sendFrequencyUpdate()
    }

    func sendFrequencyUpdate() {
        let hexFreq = String(format: "%06X", frequencyHz * 100)
        var command = "404100" + hexFreq + "00"

        switch direction.uppercased() {
        case "BID": command += "80"
        case "180": command += "40"
        case "34": command += "20"
        default: command += "00"
        }

        command += "31000D"
        log("📤 SteppIR: Sending frequency update command \(command)")
        if let data = hexStringToData(command) {
            connection?.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    /// Begin continuously receiving data on the connection
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

    private func pollStatus() {
        log("🔄 SteppIR: Polling status...")
        let command: [UInt8] = [0x3F, 0x41, 0x0D]
        connection?.send(content: Data(command), completion: .contentProcessed { _ in })
    }

    private func handleIncoming(data: Data) {
        log("📥 SteppIR: Received \(data.count) bytes: \(data as NSData)")
        buffer.append(data)

        while let terminatorRange = buffer.range(of: Data([0x0D])) {
            let frame = buffer.subdata(in: 0..<terminatorRange.upperBound)
            buffer.removeSubrange(0..<terminatorRange.upperBound)
            processResponseSteppir(frame)
        }
    }

    private func processResponseSteppir(_ data: Data) {
        let hexString = data.map { String(format: "%02X", $0) }.joined()
        log("🔄 SteppIR: Processing frame \(hexString)")

        guard hexString.hasPrefix("4041"), hexString.count >= 20 else {
            log("⚠️ SteppIR: Ignoring non-matching or short frame.")
            return
        }

        DispatchQueue.main.async {
            if let freqHex = Int(hexString.dropFirst(6).prefix(6), radix: 16) {
                self.frequencyHz = freqHex / 100
                self.log("✅ SteppIR: Parsed frequency = \(self.frequencyHz) Hz")
            }

            let tuningByte = hexString.dropFirst(12).prefix(2)
            self.tuningStatus = (tuningByte != "00")
            self.log("🎚️ SteppIR: Tuning status = \(self.tuningStatus)")

            let dirBits = (Int(hexString.dropFirst(14).prefix(2), radix: 16) ?? 0) & 0xE0
            switch dirBits >> 5 {
            case 0: self.direction = "Normal"
            case 2: self.direction = "180"
            case 3: self.direction = "3/4"
            case 4: self.direction = "BID"
            default: self.direction = "Normal"
            }
            self.log("🎯 SteppIR: Direction = \(self.direction)")
        }

        let trackByteHex = hexString.dropFirst(14).prefix(2)
        if let trackByte = UInt8(trackByteHex, radix: 16) {
            let isAuto = (trackByte & 0x04) >> 2
            DispatchQueue.main.async {
                self.isTrackingEnabled = (isAuto == 1)
                self.log("📡 SteppIR: Auto tracking is \(self.isTrackingEnabled ? "enabled" : "disabled")")
            }
        }
    }

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
            connection?.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    func setAuto(enabled: Bool) {
        pollingTimer?.invalidate()
        pollingTimer = nil

        let hexFreq = String(format: "%06X", frequencyHz * 100)
        var command = "404100" + hexFreq + "00"

        switch direction.uppercased() {
        case "BID": command += "80"
        case "180": command += "40"
        case "34": command += "20"
        default: command += "00"
        }

        let toggleCode = isTrackingEnabled ? "55" : "52"
        command += toggleCode + "000D"

        log("SteppIR: Sending AUTO command \(command)")
        if let data = hexStringToData(command) {
            connection?.send(content: data, completion: .contentProcessed { _ in })
        }

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.pollStatus()
        }
        if let timer = pollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

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
            connection?.send(content: data, completion: .contentProcessed { _ in })
        }
    }




    deinit {
        // Ensure TCP is closed if the instance is destroyed
        disconnect()
    }

}

extension SteppIRDevice {
    func updateConnectionDetails(ipAddress: String, port: Int) {
        self.ipAddress = ipAddress
        self.port = port
    }
}
