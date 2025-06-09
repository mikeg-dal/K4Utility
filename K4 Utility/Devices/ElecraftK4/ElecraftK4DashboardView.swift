//
//  ElecraftK4DashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

/// A SwiftUI view that displays the dashboard for the Elecraft K4
/// transceiver,showing connection status, current frequency,
/// power metrics, and meters.
///
struct ElecraftK4DashboardView: View {
    /// The observed Elecraft K4 device which provides published
    /// properties such as frequency, power, and connection
    /// status.
    @ObservedObject var device: ElecraftK4Device
    @State private var isTuning: Bool = false
    
    private var frequencyText: String {
        if device.isConnected {
            return device.formattedFrequency.isEmpty ? "" : "\(device.formattedFrequency) MHz"
        } else {
            return "–"
        }
    }
    

    var body: some View {
        DeviceCardContainer(title: "K4D", isConnected: device.isConnected) {
            // Your content without repeating the header
        
            Text(frequencyText)
                .bold()

            HStack(spacing: 8) {
                Button(action: {
                    if isTuning {
                        device.stopTune()
                    } else {
                        device.startTune()
                    }
                    isTuning.toggle()
                }) {
                    let tuneButtonColor = isTuning
                        ? Color(red: 66/255, green: 100/255, blue: 157/255)
                        : Color(red: 61/255, green: 61/255, blue: 61/255)
                    Text("Tune")
                        .frame(minWidth: 30)
                        .font(.caption2)
                        .padding(6)
                        .background(tuneButtonColor)
                        .foregroundColor(.white)
                        .cornerRadius(1)
                    macroButton(index: 0)
                }
                .buttonStyle(PlainButtonStyle())
            }

            HStack(spacing: 8) {
                macroButton(index: 1)
                macroButton(index: 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "Fwd: %.0f W   Ref: %.0f W", device.forwardPower, device.reflectedPower))
                    .font(.caption)
                Text(String(format: "SWR: %.1f", device.swr))
                    .font(.caption)
            }

            GradientMeterView(value: device.forwardPower,
                              minValue: 0,
                              maxValue: 100)
                .frame(width: 90, height: 16)
                .animation(.easeOut(duration: 0.5), value: device.forwardPower)
                .cornerRadius(1)

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

// MARK: – Safe Array Access

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
