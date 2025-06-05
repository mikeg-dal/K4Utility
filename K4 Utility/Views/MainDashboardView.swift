//
//  MainDashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import SwiftUI

/// The main dashboard view that lays out and displays the individual device dashboards:
/// SteppIR, Elecraft KPA-1500, Elecraft K4, and GHRT21 rotator.
/// It provides a unified, dark-themed background and arranges device-specific subviews.
struct MainDashboardView: View {
    // MARK: – Observed Device Objects

    /// The SteppIR antenna controller device, passed to its dashboard view.
    @ObservedObject var steppirDevice: SteppIRDevice

    /// The Elecraft K4 transceiver device, passed to its dashboard view.
    @ObservedObject var elecraftDevice: ElecraftK4Device

    /// The Elecraft KPA-1500 amplifier device, passed to its dashboard view.
    @ObservedObject var kpaDevice: ElecraftKPA1500Device

    /// The GreenHeron RT-21 rotator device, passed to its dashboard view.
    @ObservedObject var rotatorDevice: GHRT21Device

    @State private var isShowingSettings: Bool = false

    // MARK: – View Body

    /// The view’s content and layout:
    /// - Provides a dark background that fills the safe area.
    /// - Arranges the SteppIR dashboard at the top-left.
    /// - Below SteppIR, displays KPA-1500 and K4 dashboards side by side.
    /// - Places the GHRT21 dashboard beneath on the left.
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                #if os(macOS)
                Color(red: 37/255, green: 37/255, blue: 37/255)
                    .ignoresSafeArea()
                #else
                Color(red: 37/255, green: 37/255, blue: 37/255)
                    .ignoresSafeArea(.all, edges: [.top, .bottom])
                #endif

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Horizontal row for amplifier and transceiver dashboards
                        HStack(alignment: .top, spacing: 12) {
                            ElecraftK4DashboardView(device: elecraftDevice)
                            ElecraftKPA1500DashboardView(device: kpaDevice)
                        }

                        // SteppIR dashboard with auto-sync from K4
                        SteppIRDashboardView(device: steppirDevice, k4Device: elecraftDevice)

                        // GHRT21 rotator dashboard below
                        GHRT21DashboardView(device: rotatorDevice, steppirDevice: steppirDevice)
                    }
                    .padding()
                    .frame(minWidth: geometry.size.width, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .top)
#if os(iOS)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                isShowingSettings.toggle()
                            } label: {
                                Image(systemName: "gear")
                            }
                        }
                    }
                    .sheet(isPresented: $isShowingSettings) {
                        ZStack {
                            Color(red: 37/255, green: 37/255, blue: 37/255)
                                .ignoresSafeArea(.container, edges: [.top, .bottom])
                            DeviceSettingsView(
                                steppirDevice: steppirDevice,
                                elecraftDevice: elecraftDevice,
                                kpaDevice: kpaDevice,
                                rotatorDevice: rotatorDevice
                            )
                        }
                    }
#endif
                }
            }
        }
    }
}
