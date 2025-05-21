// GHRT21DashboardView.swift
// K4 Utility
//
// Created by Mike Garcia on 5/21/25.

import SwiftUI

struct GHRT21DashboardView: View {
    @ObservedObject var device: GHRT21Device
    private let beamwidth: Double = 66.0    // degrees

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

            // Azimuth map with beam overlay
            ZStack {
                AzimuthMapView()
                BeamWedgeShape(
                    heading: Double(device.status) ?? 0,
                    beamwidth: beamwidth
                )
                .fill(Color.green.opacity(0.3))
                .animation(.easeOut(duration: 0.3), value: device.status)
            }
            .frame(width: 200, height: 200)
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
        return GHRT21DashboardView(device: dev)
    }
}
#endif
