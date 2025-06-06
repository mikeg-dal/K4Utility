//
//  GHRT21DashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

/// A SwiftUI view that displays the dashboard for the GreenHeron RT-21 rotator,
/// showing connection status, current heading with beam wedge visualization, preset buttons, and step controls.
struct GHRT21DashboardView: View {
    /// The observed GHRT21Device providing published status, connection, and preset data.
    @ObservedObject var device: GHRT21Device

    /// An observed SteppIRDevice used to determine if a 180° flip should be applied to the heading.
    @ObservedObject var steppirDevice: SteppIRDevice

    /// The beamwidth (in degrees) used to draw the wedge overlay on the azimuth map.
    private let beamwidth: Double = 66.0

    /// Computes the rotor heading based on the device status and applies a 180° flip if `steppirDevice.direction == .deg180`.
    private var computedHeading: Double {
        let raw = Double(device.status) ?? 0
        return steppirDevice.direction == .deg180
            ? fmod(raw + 180, 360)
            : raw
    }

    // MARK: – Preset Grid

    /// A grid of preset buttons (2 rows, 4 columns) that send `goToPreset(at:)` commands to `device`.
    private var presetGrid: some View {
        VStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { col in
                        let index = row * 4 + col
                        Button(action: {
                            device.goToPreset(at: index)
                        }) {
                            VStack {
                                Text(device.presetNames[index])
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text("\(device.presetAzimuths[index])°")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .frame(minWidth: 50)
                            .padding(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(Color(red: 61/255, green: 61/255, blue: 61/255))
                        .foregroundColor(.white)
                        .cornerRadius(2)
                    }
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: – Connection Status

            /// A horizontal stack with a colored circle (green when connected, red when disconnected)
            /// and the label "GH-RT21" to indicate connection status.
            HStack(spacing: 8) {
                Circle()
                    .fill(device.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text("GH-RT21")
                    .font(.headline)
            }

            // Heading display moved here
            Text("\(Int(computedHeading))°")
                .font(.caption2)
                .padding(.top, 4)

            // MARK: – Heading Visualization

            /// Displays an AzimuthMapView overlaid with a BeamWedgeShape indicating the current heading.
            HStack {
                ZStack {
                    AzimuthMapView()
                    BeamWedgeShape(
                        heading: computedHeading,
                        beamwidth: beamwidth
                    )
                    .fill(Color.gray.opacity(0.55))
                    .animation(.easeOut(duration: 0.3), value: computedHeading)
                }
                .frame(width: 200, height: 200)
            }
            .frame(maxWidth: .infinity)

            // MARK: – Preset Buttons

            /// The grid of preset buttons allowing the user to send the rotator to stored headings.
            HStack {
                Spacer()
                presetGrid
                Spacer()
            }

            // MARK: – Step Controls

            /// A step control button that sends `stopMotion()` to the device when tapped.
            HStack(spacing: 8) {
                Button("■") {
                    device.stopMotion()
                }
                .buttonStyle(PlainButtonStyle())
                .frame(minWidth: 40)
                .font(.caption2)
                .padding(6)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .foregroundColor(.white)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 37/255, green: 37/255, blue: 37/255))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
        )
    }
}
