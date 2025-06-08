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
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(0..<2, id: \.self) { row in
                GridRow {
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
                        }
                    }
                }
            }
        }
    }
    var body: some View {
        DeviceCardContainer {
            DeviceHeader(title: "GH-RT21", isConnected: device.isConnected)
            Text("\(Int(computedHeading))°")
                .font(.caption2)

            VStack(alignment: .center) {
                // MARK: – Heading Visualization
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
                presetGrid
                    .frame(maxWidth: .infinity, alignment: .center)

                // MARK: – Step Controls
                HStack(spacing: 8) {
                    Button("■") {
                        device.stopMotion()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .modifier(RedCapsuleButtonStyle())
                }
                .padding(.top, 8)
            }
        }
    }

}

// MARK: - RedCapsuleButtonStyle
struct RedCapsuleButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption2)
            .padding(6)
            .frame(minWidth: 40)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}
