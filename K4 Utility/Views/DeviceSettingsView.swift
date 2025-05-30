//
//  DeviceSettingsView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/20/25.
//

import SwiftUI

struct DeviceSettingsView: View {
    @ObservedObject var steppirDevice: SteppIRDevice
    @ObservedObject var elecraftDevice: ElecraftK4Device
    @ObservedObject var kpaDevice: ElecraftKPA1500Device
    @ObservedObject var rotatorDevice: GHRT21Device


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

