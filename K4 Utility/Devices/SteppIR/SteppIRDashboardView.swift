//
//  SteppIRDashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI
import Combine

/// A SwiftUI view that displays the dashboard for the SteppIR
/// antenna controller, showing connection status, tuning status,
/// frequency display, control buttons, and band presets.
/// Also auto-syncs frequency from an Elecraft K4 device when
/// tracking is disabled.
struct SteppIRDashboardView: View {
    /// The observed SteppIRDevice which provides published
    /// state such as frequency, direction, and tuning status.
    @ObservedObject var device: SteppIRDevice

    /// The observed ElecraftK4Device used for auto-syncing
    /// frequency when SteppIR is not in tracking mode.
    @ObservedObject var k4Device: ElecraftK4Device

    var body: some View {
        innerDashboard
    }

    private var innerDashboard: some View {
        VStack(alignment: .center, spacing: 12) {
            // MARK: – SteppIR Card
            DeviceCardContainer(title: "SteppIR", isConnected: device.isConnected) {
                // MARK: – Tuning Status
                HStack(spacing: 8) {
                    Circle()
                        .frame(width: 12, height: 12)
                        .foregroundColor(device.tuningStatus ? .red : .gray)
                    Text("Tuning")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: – Frequency Display
                HStack {
                    Text(displayFrequencyText)
                        .bold()
                }

                // MARK: – Control & Direction Buttons
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button("Norm") {
                            device.requestDirectionChange(.normal)
                        }
                        .font(.caption)
                        .padding(6)
                        .background(device.direction == .normal
                                    ? Color(red: 66/255, green: 100/255, blue: 157/255)
                                    : Color(red: 61/255, green: 61/255, blue: 61/255))
                        .foregroundColor(.white)
                        .cornerRadius(2)
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(1.10)

                        Button("180") {
                            device.requestDirectionChange(.deg180)
                        }
                        .font(.caption)
                        .padding(6)
                        .background(device.direction == .deg180
                                    ? Color(red: 66/255, green: 100/255, blue: 157/255)
                                    : Color(red: 61/255, green: 61/255, blue: 61/255))
                        .foregroundColor(.white)
                        .cornerRadius(2)
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(1.10)

                        Button("BID") {
                            device.requestDirectionChange(.bidirectional)
                        }
                        .font(.caption)
                        .padding(6)
                        .background(device.direction == .bidirectional
                                    ? Color(red: 66/255, green: 100/255, blue: 157/255)
                                    : Color(red: 61/255, green: 61/255, blue: 61/255))
                        .foregroundColor(.white)
                        .cornerRadius(2)
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(1.10)
                    }
                    HStack(spacing: 12) {
                        Button("Home") {
                            device.setHome()
                        }
                        .font(.caption)
                        .padding(6)
                        .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                        .foregroundColor(.white)
                        .cornerRadius(2)
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(1.10)

                        Button(device.isTrackingEnabled ? "Auto On" : "Auto On") {
                            device.setAuto(enabled: !device.isTrackingEnabled)
                        }
                        .font(.caption)
                        .padding(6)
                        .background(device.isTrackingEnabled
                                    ? Color(red: 66/255, green: 100/255, blue: 157/255)
                                    : Color(red: 61/255, green: 61/255, blue: 61/255))
                        .foregroundColor(.white)
                        .cornerRadius(2)
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(1.10)

                        Button("Calibrate") {
                            device.setCalibrate()
                        }
                        .font(.caption)
                        .padding(6)
                        .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                        .foregroundColor(.white)
                        .cornerRadius(2)
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(1.10)
                    }
                }

                // MARK: – Band Preset Buttons
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        ForEach([(80, 3650), (60, 5125), (40, 7150), (30, 10125), (20, 14200)], id: \.0) { band in
                            let isActive = abs(device.frequencyHz - band.1) <= 200
                            Button("\(band.0)m") {
                                device.frequencyHz = band.1
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(minWidth: 30)
                            .font(.caption2)
                            .padding(3)
                            .background(isActive
                                        ? Color(red: 66/255, green: 100/255, blue: 157/255)
                                        : Color(red: 61/255, green: 61/255, blue: 61/255))
                            .foregroundColor(.white)
                            .cornerRadius(2)
                            .scaleEffect(1.10)
                        }
                    }
                    HStack(spacing: 12) {
                        ForEach([(17, 18125), (15, 21200), (12, 24915), (10, 28300), (6, 50300)], id: \.0) { band in
                            let isActive = abs(device.frequencyHz - band.1) <= 200
                            Button("\(band.0)m") {
                                device.frequencyHz = band.1
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(minWidth: 30)
                            .font(.caption2)
                            .padding(3)
                            .background(isActive
                                        ? Color(red: 66/255, green: 100/255, blue: 157/255)
                                        : Color(red: 61/255, green: 61/255, blue: 61/255))
                            .foregroundColor(.white)
                            .cornerRadius(2)
                            .scaleEffect(1.10)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(8)
        }
    }

    private var displayFrequencyText: String {
        let khz = device.frequencyHz
        guard khz > 0 else { return "" }
        // Convert kHz to MHz
        let mhz = Double(khz) / 1000
        // Floor to nearest 0.01 MHz (10 kHz)
        let roundedMHz = floor(mhz * 100) / 100
        return String(format: "%.3f MHz", roundedMHz)
    }
}
