//
//  DeviceSettingsView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/20/25.
//

import SwiftUI

/// A SwiftUI view that provides a tab-based interface for configuring each connected device.
/// Contains tabs for SteppIR, Elecraft K4, KPA-1500, and GreenHeron RT-21 rotator.
struct DeviceSettingsView: View {
    // MARK: – Observed Device Objects

    /// The SteppIR antenna controller device, passed to its configuration view.
    @ObservedObject var steppirDevice: SteppIRDevice

    /// The Elecraft K4 transceiver device, passed to its configuration view.
    @ObservedObject var elecraftDevice: ElecraftK4Device

    /// The Elecraft KPA-1500 amplifier device, passed to its configuration view.
    @ObservedObject var kpaDevice: ElecraftKPA1500Device

    /// The GreenHeron RT-21 rotator device, passed to its configuration view.
    @ObservedObject var rotatorDevice: GHRT21Device

    // MARK: – View Body

    /// The view’s content, which is a TabView containing configuration views for each device.
    /// - SteppIR tab: shows SteppIRConfigView.
    /// - K4D tab: shows ElecraftK4ConfigView.
    /// - KPA1500 tab: shows ElecraftKPA1500ConfigView inside a VStack.
    /// - GreenHeron tab: shows GHRT21ConfigView.
    var body: some View {
        TabView {
            // SteppIR tab
            SteppIRConfigView(device: steppirDevice)
                .tabItem {
                    Label("SteppIR", systemImage: "antenna.radiowaves.left.and.right")
                }

            // K4D tab
            ElecraftK4ConfigView(device: elecraftDevice)
                .tabItem {
                    Label("K4D", systemImage: "radio")
                }

            // KPA-1500 tab
            VStack(alignment: .leading) {
                ElecraftKPA1500ConfigView(device: kpaDevice)
            }
            .tabItem {
                Label("KPA1500", systemImage: "bolt.fill")
            }

            // GreenHeron rotator tab
            GHRT21ConfigView(device: rotatorDevice)
                .tabItem {
                    Label("GreenHeron", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(minWidth: 350, maxWidth: 400, minHeight: 240)
        .padding()
    }
}
