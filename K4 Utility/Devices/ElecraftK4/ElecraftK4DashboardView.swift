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

            // Power metrics
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "Fwd: %.0f W   Ref: %.0f W", device.forwardPower, device.reflectedPower))
                    .font(.caption)
                Text(String(format: "SWR: %.1f", device.swr))
                    .font(.caption)
            }

            // Forward power meter
            GradientMeterView(value: device.forwardPower,
                              minValue: 0,
                              maxValue: 100)
                .frame(width: 90, height: 16)
                .animation(.easeOut(duration: 0.5), value: device.forwardPower)
                .cornerRadius(1)

            // Meter value label
            Text(String(format: "%.0f W", device.forwardPower))
                .font(.caption)
        }
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
        )
    }
}
