//
//  GHRT21Device.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import Foundation
import Network

/// Handles TCP/IP communication and polling for the GreenHeron RT-21 rotator
class GHRT21Device: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var status: String = ""
    @Published var debugEnabled: Bool = false

    private var connection: NWConnection?
    private var buffer = Data()
    private var pollingTimer: Timer?

    var ipAddress: String = "192.168.1.8"
    var port: Int = 6555

    /// Helper for conditional logging
    private func log(_ message: String) {
        if debugEnabled {
            print("🛰️ GHRT21: \(message)")
        }
    }

    /// Establishes TCP connection and starts polling
    func connect() {
        log("🔗 GHRT21: Attempting to connect to \(ipAddress):\(port)")
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
                    self?.log("✅ GHRT21: Connection ready")
                    self?.startReceiveLoop()
                    // start polling every second
                    self?.pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        self?.pollStatus()
                    }
                    if let t = self?.pollingTimer {
                        RunLoop.main.add(t, forMode: .common)
                    }
                case .failed(let error):
                    self?.isConnected = false
                    self?.log("❌ GHRT21: Connection failed – \(error.localizedDescription)")
                case .cancelled:
                    self?.isConnected = false
                    self?.log("🔌 GHRT21: Connection cancelled")
                default:
                    break
                }
            }
        }
        conn.start(queue: .main)
    }

    /// Disconnects and stops polling
    func disconnect() {
        log("🔌 GHRT21: Disconnecting")
        pollingTimer?.invalidate()
        pollingTimer = nil
        connection?.cancel()
        connection = nil
        isConnected = false
    }

    /// Send the AI; command to request current status from the rotator
    private func pollStatus() {
        let cmd = "AI;"
        log("Sending command \(cmd)")
        if let data = cmd.data(using: .ascii) {
            connection?.send(content: data, completion: .contentProcessed { _ in })
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

    /// Continuously receive incoming data
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

    /// Default rotator presets (azimuths in degrees)
    let presets: [Int] = [0, 45, 90, 135, 180, 225, 270, 315]

    /// Sends a “go to” command for a specific heading
    func goTo(_ heading: Int) {
        let work = String(format: "%03d", heading)
        let cmd = "AP0" + work + "\r;"
        log("🛰️ GHRT21: Sending preset command \(cmd)")
        if let data = cmd.data(using: .ascii) {
            connection?.send(content: data, completion: .contentProcessed { _ in })
        }
   
    }

    /// Stop any ongoing relative motion
    func stopMotion() {
        let cmd = "ST;"
        log("🛰️ GHRT21: Sending stop command \(cmd)")
        if let data = cmd.data(using: .ascii) {
            connection?.send(content: data, completion: .contentProcessed { _ in })
        }
    }
}
