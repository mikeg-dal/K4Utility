//
//  GHRT21DashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

/// A SwiftUI view that displays the dashboard for the GreenHeron
/// RT-21 rotator,showing connection status, current heading with
/// beam wedge visualization, preset buttons, and step controls.
///
struct GHRT21DashboardView: View {
    /// The observed GHRT21Device providing published status,
    /// connection, and preset data.
    @ObservedObject var device: GHRT21Device

    /// An observed SteppIRDevice used to determine if a 180
    /// flip should be applied to the heading.
    @ObservedObject var steppirDevice: SteppIRDevice

    /// The beamwidth (in degrees) used to draw the wedge overlay on the azimuth map.
    private let beamwidth: Double = 66.0

    @State private var draggedAzimuth: Double? = nil
    @State private var dragStartAzimuth: Double? = nil
    @State private var dragStartAngle: Double? = nil

    /// Computes the rotor heading based on the device status and applies a 180° flip if `steppirDevice.direction == .deg180`.
    private var computedHeading: Double {
        let raw = Double(device.status) ?? 0
        return steppirDevice.direction == .deg180
            ? fmod(raw + 180, 360)
            : raw
    }

    // MARK: – Preset Grid

    /// A grid of preset buttons (2 rows, 4 columns) that send
    ///  `goToPreset(at:)` commands to `device`.
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
        DeviceCardContainer(title: "GHRT21", isConnected: device.isConnected) {
            Text("\(Int(computedHeading))°")
                .font(.caption2)

            VStack(alignment: .center) {
                // MARK: – Heading Visualization
                HStack {
                    GeometryReader { geo in
                        ZStack {
                            AzimuthMapView()

                            // Actual heading (gray)
                            BeamWedgeShape(
                                heading: computedHeading,
                                beamwidth: beamwidth
                            )
                            .fill(Color.gray.opacity(0.55))
                            .animation(.easeOut(duration: 0.3), value: computedHeading)

                            // Dragged preview (red)
                            if let preview = draggedAzimuth {
                                BeamWedgeShape(
                                    heading: preview,
                                    beamwidth: beamwidth
                                )
                                .fill(Color.red.opacity(0.5))
                            }

                            Circle()
                                .fill(Color.clear)
                                .contentShape(Circle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let loc = value.location
                                            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                            let dx = loc.x - center.x
                                            let dy = center.y - loc.y
                                            let radians = atan2(dy, dx)
                                            let degrees = radians * 180 / .pi
                                            let angle = degrees < 0 ? degrees + 360 : degrees

                                            if dragStartAzimuth == nil || dragStartAngle == nil {
                                                let offset = dx < 0 ? -10.0 : 10.0
                                                dragStartAzimuth = fmod(computedHeading + offset + 360, 360)
                                                dragStartAngle = angle
                                                draggedAzimuth = dragStartAzimuth
                                            } else if let startAz = dragStartAzimuth, let startAngle = dragStartAngle {
                                                let delta = angle - startAngle
                                                let updated = fmod(startAz - delta + 360, 360)
                                                draggedAzimuth = updated
                                            }
                                        }
                                        .onEnded { value in
                                            let loc = value.location
                                            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                            let dx = loc.x - center.x
                                            let dy = center.y - loc.y
                                            let radians = atan2(dy, dx)
                                            let degrees = radians * 180 / .pi
                                            let angle = degrees < 0 ? degrees + 360 : degrees

                                            if let startAz = dragStartAzimuth, let startAngle = dragStartAngle {
                                                let delta = angle - startAngle
                                                let finalAz = fmod(startAz - delta + 360, 360)
                                                device.goToAzimuth(degrees: Int(finalAz))
                                            }

                                            draggedAzimuth = nil
                                            dragStartAzimuth = nil
                                            dragStartAngle = nil
                                        }
                                )
                        }
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
