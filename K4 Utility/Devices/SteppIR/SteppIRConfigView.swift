//
// SteppIRConfigView.swift
// K4 Utility
//
// Created by Mike Garcia on 5/21/25.
//

import SwiftUI

struct SteppIRConfigView: View {
    @ObservedObject var device: SteppIRDevice
    @State private var showErrorAlert = false
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        Group {
            Form {
                // Debug toggle
                Toggle("Debug", isOn: $device.debugEnabled)
                    .padding(.bottom, 8)

                // Connection settings
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        TextField("IP Address", text: $device.ipAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)
                        TextField("Port", value: $device.port, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                    }
                    HStack {
                        Button(device.isConnected ? "Disconnect" : "Connect") {
                            if device.isConnected {
                                device.disconnect()
                            } else {
                                device.connect()
                            }
                        }
                        Circle()
                            .fill(device.isConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .frame(minWidth: 350, maxWidth: 400)
        .onReceive(device.$connectionError) { error in
            showErrorAlert = (error != nil)
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Connection Error"),
                message: Text(device.connectionError ?? "Unknown error"),
                dismissButton: .default(Text("OK")) {
                    device.connectionError = nil
                }
            )
        }
    }
}

