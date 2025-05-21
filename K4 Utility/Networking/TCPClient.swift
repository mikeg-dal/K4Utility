//
//  TCPClient.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import Foundation
import Network

class TCPClient {
    // MARK: - Debug Control
    private static var debugUsageCount: Int = 0
    static var debugEnabled: Bool {
        return debugUsageCount > 0
    }
    static func enableDebug() {
        debugUsageCount += 1
    }
    static func disableDebug() {
        debugUsageCount = max(0, debugUsageCount - 1)
    }
    private static func log(_ message: String) {
        if debugEnabled {
            print("📡 TCPClient: \(message)")
        }
    }

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "TCPClientQueue")

    var onReceive: ((Data) -> Void)?
    
    func connect(host: String, port: UInt16) {
        let nwEndpoint = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        connection = NWConnection(host: nwEndpoint, port: nwPort, using: .tcp)

        connection?.stateUpdateHandler = { state in
            TCPClient.log("Connection state: \(state)")
        }

        connection?.start(queue: queue)
        receive()
    }

    func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                TCPClient.log("Send error: \(error)")
            }
        }))
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data = data {
                TCPClient.log("Received \(data.count) bytes")
                self?.onReceive?(data)
            }
            if error == nil {
                self?.receive() // Continue receiving
            }
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }
}
