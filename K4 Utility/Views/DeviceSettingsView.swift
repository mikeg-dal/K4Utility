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

    @ObservedObject var settingsStore: SettingsStore
    
    // MARK: – View Body
    
    /// The view’s content, which is a TabView containing configuration views for each device.
    /// - SteppIR tab: shows SteppIRConfigView.
    /// - K4D tab: shows ElecraftK4ConfigView.
    /// - KPA1500 tab: shows ElecraftKPA1500ConfigView inside a VStack.
    /// - GreenHeron tab: shows GHRT21ConfigView.
    var body: some View {
        ZStack {
            Color(red: 37/255, green: 37/255, blue: 37/255)
                .ignoresSafeArea()
            TabView {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Debug for All Devices", isOn: Binding(
                        get: {
                            steppirDevice.debugEnabled &&
                            elecraftDevice.debugEnabled &&
                            kpaDevice.debugEnabled &&
                            rotatorDevice.debugEnabled
                        },
                        set: { newValue in
                            steppirDevice.debugEnabled = newValue
                            elecraftDevice.debugEnabled = newValue
                            kpaDevice.debugEnabled = newValue
                            rotatorDevice.debugEnabled = newValue
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .padding()
                    
                    Toggle("Connect Devices on App Startup", isOn: $settingsStore.settings.autoConnectEnabled)
                        .toggleStyle(.checkbox)
                        .padding(.horizontal)
                    
                    GroupBox(label: Label("Enable", systemImage: "checkmark.circle")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("K4", isOn: $settingsStore.settings.k4.isEnabled)
                                .toggleStyle(.checkbox)
                            Toggle("KPA", isOn: $settingsStore.settings.kpa1500.isEnabled)
                                .toggleStyle(.checkbox)
                            Toggle("Rotor", isOn: $settingsStore.settings.ghrt21.isEnabled)
                                .toggleStyle(.checkbox)
                            Toggle("SteppIR", isOn: $settingsStore.settings.steppIR.isEnabled)
                                .toggleStyle(.checkbox)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.horizontal)
                }
                .tabItem {
                    Label("Global Config", systemImage: "gearshape")
                }
                
                // SteppIR tab
                SteppIRConfigView(device: steppirDevice)
                    .tabItem {
                        Label("SteppIR Config", systemImage: "antenna.radiowaves.left.and.right")
                    }
                
                // K4D tab
                ElecraftK4ConfigView(device: elecraftDevice)
                    .tabItem {
                        Label("K4 Config", systemImage: "radio")
                    }
                
                // KPA-1500 tab
                ElecraftKPA1500ConfigView(device: kpaDevice)
                    .tabItem {
                        Label("KPA Config", systemImage: "bolt.fill")
                    }
                
                // GreenHeron rotator tab
                GHRT21ConfigView(device: rotatorDevice)
                    .tabItem {
                        Label("Rotator Config", systemImage: "arrow.triangle.2.circlepath")
                    }
            }
            .scrollDismissesKeyboard(.immediately)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
#if os(macOS)
            .frame(minWidth: 350, maxWidth: 400, minHeight: 240)
#endif
        }
    }
}
