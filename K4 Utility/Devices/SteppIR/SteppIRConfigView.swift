//
//  SteppIRConfigView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.

import SwiftUI

/// A SwiftUI view for configuring the SteppIR antenna controller’s connection
///  settings, including IP address, port,  and connect/disconnect controls.
///
struct SteppIRConfigView: View {
    /// The observed SteppIRDevice instance whose settings can be modified.
    @ObservedObject var device: SteppIRDevice

    /// Tracks whether an error alert should be presented when a connection error occurs.
    @State private var showErrorAlert = false

    /// Access to the shared settings store (injected via environment) for persisting device settings.
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()

            Form {

                // MARK: – Connection Settings
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        TextField("IP Address", text: $device.ipAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)

                        TextField("Port", value: $device.port, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                    }
                    HStack(spacing: 8) {
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
            .navigationTitle("SteppIR Settings")

        }
        // MARK: – Connection Error Handling

        /// Listens for changes to `device.connectionError`. If non-nil, triggers an alert.
        
        .onReceive(device.$connectionError) { error in
            showErrorAlert = (error != nil)
        }
        /// Presents an alert if a connection error occurs, displaying the error message.
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Connection Error"),
                message: Text(device.connectionError ?? "Unknown error"),
                dismissButton: .default(Text("OK")) {
                    // Clear the error so the alert does not reappear.
                    device.connectionError = nil
                }
            )
        }
    }
}
