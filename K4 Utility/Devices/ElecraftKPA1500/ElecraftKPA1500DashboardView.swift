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
        VStack(alignment: .leading, spacing: 12) {
            // Connection status
            HStack(spacing: 8) {
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

            // Forward power meter
            GradientMeterView(value: device.forwardPower,
                              minValue: 0,
                              maxValue: 1500)
                .frame(width: 200, height: 16)
                .animation(.easeOut(duration: 0.5), value: device.forwardPower)
                .cornerRadius(8)

            // Meter value label
            Text(String(format: "%.0f W", device.forwardPower))
                .font(.caption)

            // SWR meter
            GradientMeterView(value: device.swr,
                              minValue: 1.0,
                              maxValue: 5.0)
                .frame(width: 200, height: 16)
                .animation(.easeOut(duration: 0.5), value: device.swr)
                .cornerRadius(8)

            // Meter value label for SWR
            Text(String(format: "SWR: %.1f", device.swr))
                .font(.caption)
        }
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
        )
    }
}

#if DEBUG
struct ElecraftKPA1500DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        ElecraftKPA1500DashboardView(device: ElecraftKPA1500Device())
    }
}
#endif
