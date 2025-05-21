//
//  SteppIRDashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

struct SteppIRDashboardView: View {
    @ObservedObject var device: SteppIRDevice

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
                     : "Not Connected")
                    .bold()
            }

            // Control buttons
            HStack(spacing: 8) {
                Button("Home") {
                    device.setHome()
                }
                Button(device.isTrackingEnabled ? "Auto On" : "Auto Off") {
                    device.setAuto(enabled: !device.isTrackingEnabled)
                }
                Button("Calibrate") {
                    device.setCalibrate()
                }
            }
            .font(.caption)
            .padding(6)
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(13)

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

            // Direction buttons
            HStack(spacing: 8) {
                ForEach(["Norm", "180", "BID", "3/4"], id: \.self) { dir in
                    Button(dir) {
                        let mapped = dir == "Norm" ? "Normal" : dir
                        device.setDirection(mapped)
                    }
                    .frame(width: 50)
                    .font(.caption)
                    .padding(6)
                    .background(device.direction == (dir == "Norm" ? "Normal" : dir) ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(13)
                }
            }

            // Tuning indicator
        }
        .padding(8)
    }
}
