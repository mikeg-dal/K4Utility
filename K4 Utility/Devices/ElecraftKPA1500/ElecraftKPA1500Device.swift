//
//  ElecraftKPA1500Device.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/20/25.
//

import Foundation
import Combine
import SwiftUI  // for SettingsStore access

class ElecraftKPA1500Device: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    @Published var powerOutput: Double = 0     // in watts
    @Published var temperature: Double = 0 {     // in °C
        didSet { log("🌡️ KPA1500: temperature changed to \(temperature) °C") }
    }
    @Published var currentBand: String = ""
    @Published var operateMode: String = ""
    @Published var isInline: Bool = false
    @Published var antennaPort: Int = 0
    @Published var forwardPower: Double = 0 {
        didSet { log("📈 KPA1500: forwardPower changed to \(forwardPower) W") }
    }
    @Published var reflectedPower: Double = 0 {
        didSet { log("📉 KPA1500: reflectedPower changed to \(reflectedPower) W") }
    }
    @Published var inputPower: Double = 0 {
        didSet { log("🔌 KPA1500: inputPower changed to \(inputPower) W") }
    }
    @Published var swr: Double = 0 {
        didSet { log("📏 KPA1500: SWR changed to \(swr)") }
    }
    @Published var paVoltage: Double = 0 {
        didSet { log("🔌 KPA1500: paVoltage changed to \(paVoltage) V") }
    }
    @Published var paCurrent: Double = 0 {
        didSet { log("🔌 KPA1500: paCurrent changed to \(paCurrent) A") }
    }

    @Published var debugEnabled: Bool = false

    /// Prints debug messages when `debugEnabled` is true
    private func log(_ message: String) {
        if debugEnabled {
            print(message)
        }
    }

    private var client: TCPClient?
    private var buffer = Data()
    private var pollingTimer: Timer?

    @Published var ipAddress: String = ""
    @Published var port: Int = 0
    private var settingsStore: SettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        // Load saved settings
        let saved = settingsStore.settings.kpa1500
        self.ipAddress = saved.ipAddress
        self.port = saved.port

        // Persist changes
        $ipAddress
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.kpa1500.ipAddress = new
            }
            .store(in: &cancellables)

        $port
            .dropFirst()
            .sink { [weak self] new in
                self?.settingsStore.settings.kpa1500.port = new
            }
            .store(in: &cancellables)
    }

    func connect() {
        log("🔗 KPA1500: Attempting to connect to \(ipAddress):\(port)")
        client = TCPClient()
        client?.onReceive = handleIncoming(data:)
        client?.onDisconnect = handleDisconnect
        let success = client?.connect(host: ipAddress, port: UInt16(port)) ?? false
        if success {
            isConnected = true
            pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                self?.pollStatus()
            }
            if let t = pollingTimer {
                RunLoop.main.add(t, forMode: .common)
            }
        } else {
            handleConnectionError()
        }
    }

    func disconnect() {
        log("🔌 KPA1500: Disconnecting")
        pollingTimer?.invalidate()
        pollingTimer = nil
        client?.disconnect()
        client?.onReceive = nil
        client = nil
        isConnected = false
    }

    private func handleConnectionError() {
        log("❌ KPA1500: Connection failed to \(ipAddress):\(port)")
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
        log("🔴 KPA1500: Connection lost")
        pollingTimer?.invalidate()
        pollingTimer = nil
        client = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionError = "Connection lost"
        }
    }

    private func pollStatus() {
        let commands = ["^BN;","^OS;","^AI;","^AP;","^PWF;","^PWI;","^PWR;","^SW;","^VI;","^TM;"]
        for cmd in commands {
            let fullCmd = cmd + "\r"
            log("🔄 KPA1500: Sending command \(cmd)")
            if let data = fullCmd.data(using: .ascii) {
                client?.send(data)
            }
        }
    }

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

    private func processFrameString(_ frame: String) {
        DispatchQueue.main.async {
            switch true {
            case frame.hasPrefix("^BN"):
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
                let code = frame.dropFirst(3)
                self.operateMode = (code == "1") ? "Operate" : "Standby"
                self.log("🟢 KPA1500: Mode = \(self.operateMode)")

            case frame.hasPrefix("^AI"):
                self.isInline = frame.dropFirst(3) == "1"
                self.log("🏷️ KPA1500: Tuner Inline = \(self.isInline)")

            case frame.hasPrefix("^AP"):
                if let num = Int(frame.dropFirst(3)) {
                    self.antennaPort = num
                }
                self.log("📡 KPA1500: Antenna Port = \(self.antennaPort)")

            case frame.hasPrefix("^PWF"):
                if let val = Double(frame.dropFirst(4)) {
                    self.forwardPower = val
                }
                self.log("📈 KPA1500: Forward Power = \(self.forwardPower) W")

            case frame.hasPrefix("^PWI"):
                if let val = Double(frame.dropFirst(4)) {
                    self.inputPower = val
                }
                self.log("🔌 KPA1500: Input Power = \(self.inputPower) W")

            case frame.hasPrefix("^PWR"):
                if let val = Double(frame.dropFirst(4)) {
                    self.reflectedPower = val
                }
                self.log("📉 KPA1500: Reflected Power = \(self.reflectedPower) W")

            case frame.hasPrefix("^SW"):
                if let val = Double(frame.dropFirst(3)) {
                    self.swr = val / 10.0
                }
                self.log("📏 KPA1500: SWR = \(self.swr)")

            case frame.hasPrefix("^VI"):
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
                if let val = Double(frame.dropFirst(3)) {
                    self.temperature = val
                }
                self.log("🌡️ KPA1500: Temperature = \(self.temperature)°C")

            default:
                break
            }
        }
    }


    /// Sends a command to set Operate (true) or Standby (false) mode
    func setOperateMode(_ enabled: Bool) {
        let code = enabled ? "1" : "0"
        let cmd = "^OS\(code);"
        let fullCmd = cmd + "\r"
        log("🔄 KPA1500: Sending Mode command \(cmd)")
        if let data = fullCmd.data(using: .ascii) {
            client?.send(data)
        }
    }
}
