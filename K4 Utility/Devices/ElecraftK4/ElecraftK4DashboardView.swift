//
// ElecraftK4DashboardView.swift
// K4 Utility
//
// Created by Mike Garcia on 5/21/25.
//

import SwiftUI

struct ElecraftK4DashboardView: View {
    @ObservedObject var device: ElecraftK4Device

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Connection status
            HStack {
                Circle()
                    .fill(device.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text("Elecraft K4D")
                    .font(.headline)
            }

            // Frequency display
            HStack {
                let hz = device.frequencyHz
                Text(hz > 0
                     ? "\(formatFrequency(hz)) MHz"
                     : "Not Connected")
                    .bold()
            }
        }
        .padding(8)
    }
}

#if DEBUG
struct ElecraftK4DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        ElecraftK4DashboardView(device: ElecraftK4Device(ipAddress: "192.168.1.10", port: 9200))
    }
}
#endif
