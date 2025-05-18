import SwiftUI

struct DeviceConfigView: View {
    @ObservedObject var steppirDevice: SteppIRDevice
    @State private var ipAddress: String = "192.168.1.18"
    @State private var port: String = "10001"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(header: Text("SteppIR Connection")) {
                TextField("IP Address", text: $ipAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)

                TextField("Port", text: $port)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 150)

                HStack {
                    Button(steppirDevice.isConnected ? "Disconnect" : "Connect") {
                        if steppirDevice.isConnected {
                            steppirDevice.disconnect()
                        } else {
                            if let portInt = Int(port) {
                                steppirDevice.updateConnectionDetails(ipAddress: ipAddress, port: portInt)
                                steppirDevice.connect()
                            }
                        }
                    }

                    Button("Close") {
                        dismiss()
                    }

                    Circle()
                        .fill(steppirDevice.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .frame(minWidth: 300)
    }
}


extension SteppIRDevice {
    func updateConnectionDetails(ipAddress: String, port: Int) {
        self.ipAddress = ipAddress
        self.port = port
    }
}
