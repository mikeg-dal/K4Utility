//
//  GHRT21ConfigView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

struct GHRT21ConfigView: View {
    @ObservedObject var device: GHRT21Device

    var body: some View {
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
                        .frame(width: 90)
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

            // MARK: – Presets Grid (4 per row)
            Section {
                VStack(spacing: 16) {
                    // Row 1: presets 1–4
                    HStack(spacing: 16) {
                        ForEach(0..<4) { i in
                            VStack(spacing: 4) {
                                TextField("", text: Binding(
                                    get: { device.presetNames[i] },
                                    set: { device.presetNames[i] = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 75)

                                TextField("", value: Binding(
                                    get: { device.presetAzimuths[i] },
                                    set: { device.presetAzimuths[i] = $0 }
                                ), formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 50)
                            }
                        }
                    }
                    // Row 2: presets 5–8
                    HStack(spacing: 16) {
                        ForEach(4..<8) { i in
                            VStack(spacing: 4) {
                                TextField("", text: Binding(
                                    get: { device.presetNames[i] },
                                    set: { device.presetNames[i] = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 75)

                                TextField("", value: Binding(
                                    get: { device.presetAzimuths[i] },
                                    set: { device.presetAzimuths[i] = $0 }
                                ), formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 50)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 350, maxWidth: 400)
    }
}

#if DEBUG
struct GHRT21ConfigView_Previews: PreviewProvider {
    static var previews: some View {
        GHRT21ConfigView(device: GHRT21Device())
    }
}
#endif
