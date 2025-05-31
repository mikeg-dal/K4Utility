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

            // Operate/Standby and Additional Controls
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Standby/Operate
                    Button(device.operateMode == "Operate" ? "Standby" : "Operate") {
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

                    // Button1
                    Button("Antenna") {
                        // TODO: Implement action
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(minWidth: 30)
                    .font(.caption2)
                    .padding(6)
                    .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                    .foregroundColor(.white)
                    .cornerRadius(1)
                }
                .padding(3)

                HStack(spacing: 8) {
                    // Button2
                    Button("ATU") {
                        // TODO: Implement action
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(minWidth: 30)
                    .font(.caption2)
                    .padding(6)
                    .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                    .foregroundColor(.white)
                    .cornerRadius(1)

                    // Button3
                    Button("Reset") {
                        // TODO: Implement action
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(minWidth: 30)
                    .font(.caption2)
                    .padding(6)
                    .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                    .foregroundColor(.white)
                    .cornerRadius(1)
                }
                .padding(3)
            }
            .padding(8)

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
