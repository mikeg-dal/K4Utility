//
//  ElecraftK4ConfigView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.

import SwiftUI

/// A SwiftUI view for configuring the Elecraft K4 device’s connection settings,
/// including IP address, port, debug toggle, and connect/disconnect controls.
struct ElecraftK4ConfigView: View {
    /// The observed Elecraft K4 device instance whose settings can be modified.
    @ObservedObject var device: ElecraftK4Device

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
            Color(red: 37/255, green: 37/255, blue: 37/255)
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
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("K4 Config")
        }
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
