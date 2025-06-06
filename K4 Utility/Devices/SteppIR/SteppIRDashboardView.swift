//
//  SteppIRDashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI
import Combine

/// A SwiftUI view that displays the dashboard for the SteppIR antenna controller,
/// showing connection status, tuning status, frequency display, control buttons, and band presets.
/// Also auto-syncs frequency from an Elecraft K4 device when tracking is disabled.
struct SteppIRDashboardView: View {
    /// The observed SteppIRDevice which provides published state such as frequency, direction, and tuning status.
    @ObservedObject var device: SteppIRDevice

    /// The observed ElecraftK4Device used for auto-syncing frequency when SteppIR is not in tracking mode.
    @ObservedObject var k4Device: ElecraftK4Device

    @Environment(\.horizontalSizeClass) var horizontalSizeClass


    var body: some View {
        // Modularized: Let parent (e.g., MainDashboardView) control all sizing/positioning.
        innerDashboard
#if os(macOS)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#endif
        // MARK: – Auto-sync SteppIR to K4 frequency
        /// Listens for frequency changes from `k4Device` and, when SteppIR auto-tracking is disabled,
        /// updates the SteppIR frequency (rounded to the nearest 10 kHz).
        .onReceive(
            k4Device.$frequencyHz
                .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
        ) { newHz in
            guard device.isTrackingEnabled else { return }
            let rawKHz = newHz / 1000
            let truncatedKHz = (rawKHz / 10) * 10
            device.frequencyHz = truncatedKHz
        }
    }

    private var innerDashboard: some View {
        ZStack {
            Color(red: 37/255, green: 37/255, blue: 37/255)
            VStack(alignment: .leading, spacing: 12) {
            // MARK: – Connection Status

            /// A horizontal stack with a colored circle (green when connected, red when disconnected)
            /// and the label "SteppIR" to indicate TCP connection status.
            HStack(spacing: 12) {
                Circle()
                    .frame(width: 12, height: 12)
                    .foregroundColor(device.isConnected ? Color.green : Color.red)
                Text("SteppIR")
                    .font(.headline)
            }

            // MARK: – Tuning Status

            /// A horizontal stack with a colored circle (red when tuning in progress, green otherwise)
            /// and the label "Tuning" to indicate current tuning status.
            HStack(spacing: 8) {
                Circle()
                    .frame(width: 12, height: 12)
                    .foregroundColor(device.tuningStatus ? Color.red : Color.gray)
                Text("Tuning")
                    .font(.headline)
            }

            // MARK: – Frequency Display

            /// Displays the current frequency in MHz with three decimal places if `device.frequencyHz` is non-zero.
            HStack {
                let hz = device.frequencyHz
                Text(hz > 0
                     ? String(format: "%.3f MHz", Double(hz) / 1000.0)
                     : "")
                    .bold()
            }

            // MARK: – Control & Direction Buttons

            /// Renders two rows of buttons for setting direction modes, home, auto-tracking toggle, and calibration.
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    /// Button to set direction to "Normal".
                    Button("Norm") {
                        device.direction = .normal
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

                    /// Button to set direction to "180".
                    Button("180") {
                        device.direction = .deg180
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

                    /// Button to set direction to "BID".
                    Button("BID") {
                        device.direction = .bidirectional
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
                    /// Button to send the "Home" command.
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

                    /// Button to toggle auto-tracking on or off.
                    Button(device.isTrackingEnabled ? "Auto On" : "Auto On") {
                        device.setAuto(enabled: !device.isTrackingEnabled)
                    }
                    .font(.caption)
                    .padding(6)
                    .background(
                        device.isTrackingEnabled
                            ? Color(red: 66/255, green: 100/255, blue: 157/255)
                            : Color(red: 61/255, green: 61/255, blue: 61/255)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(2)
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(1.10)

                    /// Button to send the "Calibrate" command.
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

                /// Renders two rows of buttons labeled with meter bands. When tapped, sets the frequency and retains direction.
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(.white)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white, lineWidth: 2)
            )
        }
    }

