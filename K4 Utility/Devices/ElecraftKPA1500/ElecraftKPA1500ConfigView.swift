//
//  ElecraftKPA1500ConfigView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/20/25.

import SwiftUI

/// A SwiftUI view for configuring the Elecraft KPA-1500 amplifier's connection
///  settings, including IP address, port, and connect/disconnect controls.
///
struct ElecraftKPA1500ConfigView: View {
    /// The observed Elecraft KPA-1500 device instance whose settings can be modified.
    @ObservedObject var device: ElecraftKPA1500Device

    /// Tracks whether an error alert should be presented when a connection error occurs.
    @State private var showErrorAlert = false

    /// Access to the shared settings store (injected via environment) for persisting device settings.
    @EnvironmentObject var settingsStore: SettingsStore

    private func bindingForName(at index: Int) -> Binding<String> {
        Binding(
            get: { device.macroNames[index] },
            set: { device.macroNames[index] = $0 }
        )
    }

    private func bindingForCommand(at index: Int) -> Binding<String> {
        Binding(
            get: { device.macroCommands[index] },
            set: { device.macroCommands[index] = $0 }
        )
    }

    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            Form {
                // MARK: – Connection Settings

                /// A section containing text fields for IP address and port,
                /// as well as a connect/disconnect button and status indicator.
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        /// Text field for editing the amplifier’s IP address, bound to `device.ipAddress`.
                        TextField("IP Address", text: $device.ipAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)

                        /// Text field for editing the amplifier’s port, bound to `device.port`.
                        TextField("Port", value: $device.port, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                    }
                    HStack {
                        /// Button that toggles between "Connect" and "Disconnect" based on `device.isConnected`.
                        /// Tapping will call `device.connect()` or `device.disconnect()`.
                        Button(device.isConnected ? "Disconnect" : "Connect") {
                            if device.isConnected {
                                device.disconnect()
                            } else {
                                device.connect()
                            }
                        }

                        /// A small circle that is green when connected and red when disconnected.
                        Circle()
                            .fill(device.isConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                    }
                }

                // MARK: – Custom Macros

                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Macros")
                        .font(.headline)
                    HStack(spacing: 16) {
                        ForEach(0..<3, id: \.self) { index in
                            VStack(spacing: 4) {
                                TextField("Name", text: bindingForName(at: index))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 112)
                                TextField("Macro", text: bindingForCommand(at: index))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 112)
                            }
                        }
                    }
                }
            }
            .navigationTitle("KPA1500 Settings")
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
