//
// ElecraftK4DashboardView.swift
// K4 Utility
//
// Created by Mike Garcia on 5/21/25.
//


import SwiftUI


struct ElecraftK4DashboardView: View {
    @ObservedObject var device: ElecraftK4Device

    private func formatFrequency(_ hz: Int) -> String {
        let mhz = hz / 1_000_000
        let remainder = hz % 1_000_000
        let khz = remainder / 1_000
        let hzRemainder = remainder % 1_000
        return String(format: "%d.%03d.%03d", mhz, khz, hzRemainder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Connection status
            HStack {
                Circle()
                    .fill(device.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text("K4D")
                    .font(.headline)
            }

            // Frequency display
            HStack {
                let hz = device.frequencyHz
                Text(hz > 0
                     ? "\(formatFrequency(hz)) MHz"
                     : "")
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
