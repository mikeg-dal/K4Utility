// DeviceConfigView.swift


import SwiftUI

struct DeviceConfigView: View {
    @ObservedObject var steppirDevice: SteppIRDevice
    @ObservedObject var elecraftDevice: ElecraftK4Device

    @State var ipAddress: String = "192.168.1.18"
    @State var port: String = "10001"

    @State var k4IpAddress: String = "192.168.1.10"
    @State var k4Port: String = "9200"

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            // SteppIR Controls
            Section(header: Text("SteppIR Connection")) {
                SteppIRConfigView(ipAddress: $ipAddress, port: $port, steppirDevice: steppirDevice)
            }

            Section(header: Text("Elecraft K4D Configuration").font(.headline)) {
                ElecraftConfigView(ipAddress: $k4IpAddress, port: $k4Port, elecraftDevice: elecraftDevice)
            }
            
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                Spacer()
            }
        }
        .frame(minWidth: 350, maxWidth: 400)
        .id(steppirDevice.isConnected.hashValue ^ elecraftDevice.isConnected.hashValue)
    }
}

// MARK: - Subviews for modular UI

struct SteppIRConfigView: View {
    @Binding var ipAddress: String
    @Binding var port: String
    var steppirDevice: SteppIRDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                TextField("IP Address", text: $ipAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                TextField("Port", text: $port)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
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
                Circle()
                    .fill(steppirDevice.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
            }
        }
    }
}

struct ElecraftConfigView: View {
    @Binding var ipAddress: String
    @Binding var port: String
    var elecraftDevice: ElecraftK4Device

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                TextField("IP Address", text: $ipAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                TextField("Port", text: $port)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
            HStack {
                Button(elecraftDevice.isConnected ? "Disconnect" : "Connect") {
                    if elecraftDevice.isConnected {
                        elecraftDevice.disconnect()
                    } else {
                        if let portInt = Int(port) {
                            elecraftDevice.updateConnectionDetails(ipAddress: ipAddress, port: portInt)
                            elecraftDevice.connect()
                        }
                    }
                }
                Circle()
                    .fill(elecraftDevice.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
            }
        }
    }
}
