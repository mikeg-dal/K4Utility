//
//  ElecraftKPA1500DashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

/// A SwiftUI view that displays the dashboard for the Elecraft KPA-1500 amplifier,
/// showing connection status, current band, mode, control buttons, and power metrics.
struct ElecraftKPA1500DashboardView: View {
    /// The observed Elecraft KPA-1500 device which provides published properties
    /// such as connection status, band, mode, and power readings.
    @ObservedObject var device: ElecraftKPA1500Device

    var body: some View {
        DeviceCardContainer {
            DeviceHeader(title: "KPA1500", isConnected: device.isConnected)

            // MARK: – Band Display
            HStack {
                Text("Band: \(device.currentBand.isEmpty ? "–" : device.currentBand)")
                    .font(.subheadline)
            }

            // MARK: – Mode Display
            HStack {
                Text("Mode: \(device.operateMode)")
                    .font(.subheadline)
            }

            // MARK: – Control Buttons
            VStack(spacing: 8) {
                // First row: Operate and M1
                HStack(spacing: 8) {
                    Button("Operate") {
                        let shouldOperate = device.operateMode != "Operate"
                        device.setOperateMode(shouldOperate)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(minWidth: 30)
                    .font(.caption2)
                    .padding(6)
                    .background(device.operateMode == "Operate"
                                ? Color(red: 66/255, green: 100/255, blue: 157/255)
                                : Color(red: 61/255, green: 61/255, blue: 61/255))
                    .foregroundColor(.white)
                    .cornerRadius(1)

                    Button(action: { sendMacro(at: 0) }) {
                        Text(macroButtonLabel(for: 0))
                            .frame(minWidth: 30)
                            .font(.caption2)
                            .padding(6)
                            .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                            .foregroundColor(.white)
                            .cornerRadius(1)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Second row: M2 and M3
                HStack(spacing: 8) {
                    ForEach(1..<3) { index in
                        Button(action: { sendMacro(at: index) }) {
                            Text(macroButtonLabel(for: index))
                                .frame(minWidth: 30)
                                .font(.caption2)
                                .padding(6)
                                .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                                .foregroundColor(.white)
                                .cornerRadius(1)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(8)

            // MARK: – Power Metrics
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "Fwd: %.0f W   Ref: %.0f W", device.forwardPower, device.reflectedPower))
                    .font(.caption)
                Text(String(format: "In: %.0f W   SWR: %.1f", device.inputPower, device.swr))
                    .font(.caption)
            }

            // MARK: – Forward Power Meter
            GradientMeterView(value: device.forwardPower,
                              minValue: 0,
                              maxValue: 1500)
                .frame(width: 90, height: 16)
                .animation(.easeOut(duration: 0.5), value: device.forwardPower)
                .cornerRadius(1)

            // MARK: – Meter Value Label
            Text(String(format: "%.0f W", device.forwardPower))
                .font(.caption)
        }
    }

    private func macroButtonLabel(for index: Int) -> String {
        if let name = device.macroNames[safe: index], !name.isEmpty {
            return name
        }
        return "M\(index + 1)"
    }

    private func sendMacro(at index: Int) {
        if index < device.macroCommands.count {
            device.sendCommand(device.macroCommands[index])
        }
    }
}
