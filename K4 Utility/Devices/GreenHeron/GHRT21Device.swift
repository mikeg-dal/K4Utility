//
//  GHRT21Device.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import Foundation

/// Handles TCP/IP communication and polling for the GreenHeron RT-21 rotator
class GHRT21Device: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var status: String = ""
    @Published var debugEnabled: Bool = false {
        didSet {
            if debugEnabled {
                TCPClient.enableDebug()
            } else {
                TCPClient.disableDebug()
            }
        }
    }

    private var client: TCPClient?
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
        client = TCPClient()
        client?.onReceive = handleIncoming(data:)
        client?.connect(host: ipAddress, port: UInt16(port))
        isConnected = true
        log("Connected to \(ipAddress):\(port)")

        // Poll AI; every second
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollStatus()
        }
        if let timer = pollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Disconnects and stops polling
    func disconnect() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        client?.disconnect()
        client?.onReceive = nil
        client = nil
        isConnected = false
        log("Disconnected")
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
}
