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
