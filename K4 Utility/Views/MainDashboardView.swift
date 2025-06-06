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

    @ObservedObject var settingsStore: SettingsStore

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
                    .ignoresSafeArea()
                #endif

                #if os(iOS)
                if geometry.size.width > geometry.size.height {
                    // Landscape mode: show all devices in a ScrollView with two rows
                    ScrollView {
                        VStack(spacing: 20) {
                            HStack(spacing: 12) {
                                if settingsStore.settings.k4.isEnabled {
                                    ElecraftK4DashboardView(device: elecraftDevice)
                                        .frame(width: geometry.size.width / 3.1)
                                }
                                if settingsStore.settings.kpa1500.isEnabled {
                                    ElecraftKPA1500DashboardView(device: kpaDevice)
                                        .frame(width: geometry.size.width / 3.1)
                                }
                                if settingsStore.settings.steppIR.isEnabled {
                                    SteppIRDashboardView(device: steppirDevice, k4Device: elecraftDevice)
                                        .frame(width: geometry.size.width / 3.1)
                                }
                            }

                            if settingsStore.settings.ghrt21.isEnabled {
                                HStack {
                                    Spacer()
                                    GHRT21DashboardView(device: rotatorDevice, steppirDevice: steppirDevice)
                                        .frame(width: geometry.size.width / 3.1)
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    // Portrait mode: two centered rows
                    VStack(spacing: 40) {
                        HStack(spacing: 12) {
                            if settingsStore.settings.k4.isEnabled {
                                ElecraftK4DashboardView(device: elecraftDevice)
                            }
                            if settingsStore.settings.kpa1500.isEnabled {
                                ElecraftKPA1500DashboardView(device: kpaDevice)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        HStack(spacing: 12) {
                            if settingsStore.settings.steppIR.isEnabled {
                                SteppIRDashboardView(device: steppirDevice, k4Device: elecraftDevice)
                            }
                            if settingsStore.settings.ghrt21.isEnabled {
                                GHRT21DashboardView(device: rotatorDevice, steppirDevice: steppirDevice)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding()
                    .frame(minWidth: geometry.size.width, alignment: .top)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                #else
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if settingsStore.settings.k4.isEnabled {
                            ElecraftK4DashboardView(device: elecraftDevice)
                        }
                        if settingsStore.settings.kpa1500.isEnabled {
                            ElecraftKPA1500DashboardView(device: kpaDevice)
                        }
                        if settingsStore.settings.steppIR.isEnabled {
                            SteppIRDashboardView(device: steppirDevice, k4Device: elecraftDevice)
                        }
                        if settingsStore.settings.ghrt21.isEnabled {
                            GHRT21DashboardView(device: rotatorDevice, steppirDevice: steppirDevice)
                        }
                    }
                    .padding()
                    .frame(minWidth: geometry.size.width, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                #endif
            }
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
                        rotatorDevice: rotatorDevice,
                        settingsStore: settingsStore
                    )
                }
            }
            #endif
        }
    }
}
