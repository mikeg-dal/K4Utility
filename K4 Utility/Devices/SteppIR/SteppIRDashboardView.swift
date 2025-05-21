//
//  SteppIRDashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI
import Combine

struct SteppIRDashboardView: View {
    @ObservedObject var device: SteppIRDevice
    @ObservedObject var k4Device: ElecraftK4Device

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Connection status
            HStack(spacing: 8) {
                Circle()
                    .fill(device.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text("SteppIR")
                    .font(.headline)
            }

            // Tuning indicator under title
            HStack(spacing: 8) {
                Circle()
                    .fill(device.tuningStatus ? Color.red : Color.green)
                    .frame(width: 12, height: 12)
                Text("Tuning")
                    .font(.headline)
            }

            // Frequency display
            HStack {
                let hz = device.frequencyHz
                Text(hz > 0
                     ? String(format: "%.3f MHz", Double(hz) / 1000.0)
                     : "")
                    .bold()
            }

            // Control & direction buttons (2 rows with individual highlights)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button("Norm") {
                        device.setDirection("Normal")
                    }
                    .font(.caption)
                    .padding(6)
                    .background(device.direction == "Normal" ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(13)

                    Button("180") {
                        device.setDirection("180")
                    }
                    .font(.caption)
                    .padding(6)
                    .background(device.direction == "180" ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(13)

                    Button("BID") {
                        device.setDirection("BID")
                    }
                    .font(.caption)
                    .padding(6)
                    .background(device.direction == "BID" ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(13)
                }
                HStack(spacing: 8) {
                    Button("Home") {
                        device.setHome()
                    }
                    .font(.caption)
                    .padding(6)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(13)

                    Button(device.isTrackingEnabled ? "Auto On" : "Auto Off") {
                        device.setAuto(enabled: !device.isTrackingEnabled)
                    }
                    .font(.caption)
                    .padding(6)
                    .background(device.isTrackingEnabled ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(13)

                    Button("Calibrate") {
                        device.setCalibrate()
                    }
                    .font(.caption)
                    .padding(6)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(13)
                }
            }

            // Band preset buttons
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach([(80, 3650), (60, 5125), (40, 7150), (30, 10125), (20, 14200)], id: \.0) { band in
                        let isActive = abs(device.frequencyHz - band.1) <= 200
                        Button("\(band.0)m") {
                            device.setFrequency(band.1)
                            device.setDirection(device.direction)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(minWidth: 30)
                        .font(.caption2)
                        .padding(3)
                        .background(isActive ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(13)
                    }
                }
                HStack(spacing: 8) {
                    ForEach([(17, 18125), (15, 21200), (12, 24915), (10, 28300), (6, 50300)], id: \.0) { band in
                        let isActive = abs(device.frequencyHz - band.1) <= 200
                        Button("\(band.0)m") {
                            device.setFrequency(band.1)
                            device.setDirection(device.direction)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(minWidth: 30)
                        .font(.caption2)
                        .padding(3)
                        .background(isActive ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(13)
                    }
                }
            }
        }
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
        )
        // Auto-sync SteppIR to K4 frequency
        .onReceive(
            k4Device.$frequencyHz
                .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
        ) { newHz in
            let rawKHz = newHz / 1000
            let truncatedKHz = (rawKHz / 10) * 10
            device.setFrequency(truncatedKHz)
            device.setDirection(device.direction)
        }
    }
}
