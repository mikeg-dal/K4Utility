//
//  ElecraftK4DashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

/// A SwiftUI view that displays the dashboard for the Elecraft K4 transceiver,
/// showing connection status, current frequency, power metrics, and meters.
struct ElecraftK4DashboardView: View {
    /// The observed Elecraft K4 device which provides published properties
    /// such as frequency, power, and connection status.
    @ObservedObject var device: ElecraftK4Device

    /// Formats an integer Hertz value into a human-readable string in the form "MHz.KHz.Hz".
    ///
    /// - Parameter hz: The frequency in Hertz (e.g., 7100000 for 7.100 MHz).
    /// - Returns: A formatted string, such as "7.100.000".
    private func formatFrequency(_ hz: Int) -> String {
        let mhz = hz / 1_000_000
        let remainder = hz % 1_000_000
        let khz = remainder / 1_000
        let hzRemainder = remainder % 1_000
        return String(format: "%d.%03d.%03d", mhz, khz, hzRemainder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: – Connection Status Indicator

            /// A small circle that is green when the device is connected and red when disconnected,
            /// accompanied by the label "K4D".
            HStack {
                Circle()
                    .fill(device.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text("K4D")
                    .font(.headline)
            }

            // MARK: – Frequency Display

            /// Shows the current frequency in MHz based on `device.frequencyHz`. If no frequency 
            /// is available (i.e., zero), the view displays nothing.
            HStack {
                let hz = device.frequencyHz
                Text(hz > 0
                     ? "\(formatFrequency(hz)) MHz"
                     : "")
                    .bold()
            }

            // MARK: – Placeholder Buttons

            /// Two rows of two placeholder buttons labeled 1–4.
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button("1") {
                        // TODO: Implement action for button 1
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(minWidth: 30)
                    .font(.caption2)
                    .padding(6)
                    .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                    .foregroundColor(.white)
                    .cornerRadius(1)

                    Button("2") {
                        // TODO: Implement action for button 2
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(minWidth: 30)
                    .font(.caption2)
                    .padding(6)
                    .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                    .foregroundColor(.white)
                    .cornerRadius(1)
                }

                HStack(spacing: 8) {
                    Button("3") {
                        // TODO: Implement action for button 3
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(minWidth: 30)
                    .font(.caption2)
                    .padding(6)
                    .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                    .foregroundColor(.white)
                    .cornerRadius(1)

                    Button("4") {
                        // TODO: Implement action for button 4
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(minWidth: 30)
                    .font(.caption2)
                    .padding(6)
                    .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                    .foregroundColor(.white)
                    .cornerRadius(1)
                }
            }
            .padding(8)
            .background(Color.clear)

            // MARK: – Power Metrics

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "Fwd: %.0f W   Ref: %.0f W", device.forwardPower, device.reflectedPower))
                    .font(.caption)
                Text(String(format: "SWR: %.1f", device.swr))
                    .font(.caption)
            }

            // MARK: – Forward Power Meter

            GradientMeterView(value: device.forwardPower,
                              minValue: 0,
                              maxValue: 100)
                .frame(width: 90, height: 16)
                .animation(.easeOut(duration: 0.5), value: device.forwardPower)
                .cornerRadius(1)

            // MARK: – Meter Value Label

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
