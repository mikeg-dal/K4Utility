//
//  ElecraftKPA1500ConfigView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/20/25.
//

import SwiftUI

struct ElecraftKPA1500ConfigView: View {
    @ObservedObject var device: ElecraftKPA1500Device

    var body: some View {
        Form {
            Section(header: Text("Elecraft KPA-1500 Configuration").font(.headline)) {
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
        
    }
}

#if DEBUG
struct ElecraftKPA1500ConfigView_Previews: PreviewProvider {
    static var previews: some View {
        ElecraftKPA1500ConfigView(device: ElecraftKPA1500Device())
    }
}
#endif
