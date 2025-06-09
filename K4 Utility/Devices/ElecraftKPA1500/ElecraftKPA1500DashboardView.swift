//
//  ElecraftKPA1500DashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

/// A SwiftUI view that displays the dashboard for the Elecraft
/// KPA-1500 amplifier,showing connection status, current band,
/// mode, control buttons,and power metrics.
///
struct ElecraftKPA1500DashboardView: View {
    /// The observed Elecraft KPA-1500 device which provides
    /// published properties such as connection status, band,
    /// mode, and power readings.
    @ObservedObject var device: ElecraftKPA1500Device

    var body: some View {
        DeviceCardContainer(title: "KPA1500", isConnected: device.isConnected) {

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

            // MARK: – Macro Buttons
            VStack(spacing: 8) {
                // First row: Operate and Macro 1
                HStack(spacing: 8) {
                    Button("Operate") {
                        let shouldOperate = device.operateMode != "Operate"
                        device.setOperateMode(shouldOperate)
                    }
                    .buttonStyle(CompactDeviceButtonStyle(isActive: device.operateMode == "Operate"))

                    macroButton(index: 0)
                }

                // Second row: Macro 2 and 3
                HStack(spacing: 8) {
                    macroButton(index: 1)
                    macroButton(index: 2)
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

    // MARK: - Macros

    private func sendMacro(at index: Int) {
        if index < device.macroCommands.count {
            device.sendCommand(device.macroCommands[index])
        }
    }

    private func macroButton(index: Int) -> some View {
        Button(device.macroLabel(at: index)) {
            sendMacro(at: index)
        }
        .buttonStyle(CompactDeviceButtonStyle())
    }
}
