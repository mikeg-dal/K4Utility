//
//  GHRT21ConfigView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

/// A SwiftUI view for configuring the GreenHeron RT-21 rotator's connection settings
/// and managing presets, including fields for IP address, port, and preset names/azimuths.
struct GHRT21ConfigView: View {
    /// The observed GHRT21Device instance whose connection settings and presets can be modified.
    @ObservedObject var device: GHRT21Device

    /// Tracks whether an error alert should be presented when a connection error occurs.
    @State private var showErrorAlert = false

    /// Access to the shared settings store (injected via environment) for persisting device settings and presets.
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        Group {
            Form {
                // MARK: – Debug Toggle

                /// A toggle switch that enables or disables debug logging for the rotator device.
                Toggle("Debug", isOn: $device.debugEnabled)
                    .padding(.bottom, 8)

                // MARK: – Connection Settings

                /// A section containing text fields for IP address and port,
                /// as well as a connect/disconnect button and a connection status indicator.
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        /// Text field for editing the rotator’s IP address, bound to `device.ipAddress`.
                        TextField("IP Address", text: $device.ipAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)

                        /// Text field for editing the rotator’s port, bound to `device.port`.
                        TextField("Port", value: $device.port, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 90)
                    }
                    HStack(spacing: 8) {
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

                // MARK: – Presets Grid (4 per row)

                /// A section containing a grid of text fields for editing preset names and azimuths (two rows of four).
                Section {
                    VStack(spacing: 16) {
                        // Row 1: presets 1–4
                        HStack(spacing: 16) {
                            ForEach(0..<4) { i in
                                VStack(spacing: 4) {
                                    /// Text field for the preset name at index `i` with azimuth shown in label.
                                    TextField("\(device.presetNames[i]) (\(device.presetAzimuths[i])°)", text: Binding(
                                        get: { device.presetNames[i] },
                                        set: { device.presetNames[i] = $0 }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 75)
                                }
                            }
                        }
                        // Row 2: presets 5–8
                        HStack(spacing: 16) {
                            ForEach(4..<8) { i in
                                VStack(spacing: 4) {
                                    /// Text field for the preset name at index `i` with azimuth shown in label.
                                    TextField("\(device.presetNames[i]) (\(device.presetAzimuths[i])°)", text: Binding(
                                        get: { device.presetNames[i] },
                                        set: { device.presetNames[i] = $0 }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 75)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 350, maxWidth: 400)

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
