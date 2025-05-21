//
//  ElecraftKPA1500DashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

struct ElecraftKPA1500DashboardView: View {
    @ObservedObject var device: ElecraftKPA1500Device

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Connection status
            HStack {
                Circle()
                    .fill(device.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text("KPA1500")
                    .font(.headline)
            }

            // Band
            HStack {
                Text("Band: \(device.currentBand.isEmpty ? "–" : device.currentBand)")
                    .font(.subheadline)
            }

            // Mode
            HStack {
                Text("Mode: \(device.operateMode)")
                    .font(.subheadline)
            }

            // Power metrics
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "Fwd: %.0f W   Ref: %.0f W", device.forwardPower, device.reflectedPower))
                    .font(.caption)
                Text(String(format: "In: %.0f W   SWR: %.1f", device.inputPower, device.swr))
                    .font(.caption)
            }

            // Voltage & current
            HStack(spacing: 16) {
                Text(String(format: "V: %.1f V", device.paVoltage))
                    .font(.caption)
                Text(String(format: "I: %.2f A", device.paCurrent))
                    .font(.caption)
            }
        }
        .padding(8)
    }
}

#if DEBUG
struct ElecraftKPA1500DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        ElecraftKPA1500DashboardView(device: ElecraftKPA1500Device())
    }
}
#endif
