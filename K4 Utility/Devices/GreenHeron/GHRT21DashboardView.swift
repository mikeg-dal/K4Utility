// GHRT21DashboardView.swift
// K4 Utility
//
// Created by Mike Garcia on 5/21/25.

import SwiftUI

struct GHRT21DashboardView: View {
    @ObservedObject var device: GHRT21Device
    @ObservedObject var steppirDevice: SteppIRDevice
    private let beamwidth: Double = 66.0    // degrees

    /// Computes rotor heading, applying 180° flip if needed
    private var computedHeading: Double {
        let raw = Double(device.status) ?? 0
        return steppirDevice.direction == "180"
            ? fmod(raw + 180, 360)
            : raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Connection status
            HStack(spacing: 8) {
                Circle()
                    .fill(device.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text("GH-RT21")
                    .font(.headline)
            }

            ZStack {
                AzimuthMapView()
                BeamWedgeShape(
                    heading: computedHeading,
                    beamwidth: beamwidth
                )
                .fill(Color.green.opacity(0.3))
                .animation(.easeOut(duration: 0.3), value: computedHeading)
            }
            .frame(width: 200, height: 200)

            // Preset heading buttons (2 rows × 4 columns)
            VStack(spacing: 8) {
                ForEach(0..<2) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<4) { col in
                            let heading = device.presets[row * 4 + col]
                            Button("\(heading)°") {
                                device.goTo(heading)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(minWidth: 40)
                            .font(.caption2)
                            .padding(6)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            // Rotator step controls
            HStack(spacing: 8) {
                Button("■") {
                    device.stopMotion()
                }
                .buttonStyle(PlainButtonStyle())
                .frame(minWidth: 40)
                .font(.caption2)
                .padding(6)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
        )
    }
}

#if DEBUG
struct GHRT21DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        // Simulate angle by setting status before previewing
        let dev = GHRT21Device()
        dev.status = "90"
        return GHRT21DashboardView(device: dev, steppirDevice: SteppIRDevice())
    }
}
#endif
