//
//  TCPClient.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import Foundation
import Network

class TCPClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "TCPClientQueue")

    var onReceive: ((Data) -> Void)?
    
    func connect(host: String, port: UInt16) {
        let nwEndpoint = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        connection = NWConnection(host: nwEndpoint, port: nwPort, using: .tcp)

        connection?.stateUpdateHandler = { state in
            print("[TCPClient] Connection state: \(state)")
        }

        connection?.start(queue: queue)
        receive()
    }

    func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                print("[TCPClient] Send error: \(error)")
            }
        }))
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data = data {
                print("[TCPClient] Received \(data.count) bytes")
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
