//
//  K4_UtilityApp.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import SwiftUI

/// The main application entry point for K4 Utility, handling app lifecycle, device instantiation,
/// and scene definitions for the main dashboard and device settings.
@main
struct K4_UtilityApp: App {
    // MARK: – State Objects (Persistent Across Scenes)

    /// The persistent settings store for application-wide configuration.
    @StateObject private var settingsStore: SettingsStore

    /// The SteppIR antenna controller device instance, shared across views.
    @StateObject private var steppirDevice: SteppIRDevice

    /// The Elecraft K4 transceiver device instance, shared across views.
    @StateObject private var k4dDevice: ElecraftK4Device

    /// The Elecraft KPA-1500 amplifier device instance, shared across views.
    @StateObject private var kpaDevice: ElecraftKPA1500Device

    /// The GreenHeron RT-21 rotator device instance, shared across views.
    @StateObject private var rotatorDevice: GHRT21Device

    /// Tracks the current scene phase (active, inactive, background) for lifecycle handling.
    @Environment(\.scenePhase) private var scenePhase

    // MARK: – Initialization

    /// Initializes the application by creating a shared `SettingsStore` and injecting it
    /// into each device wrapper, so device IP/port settings are persisted.
    init() {
        let store = SettingsStore()
        _settingsStore = StateObject(wrappedValue: store)
        _steppirDevice = StateObject(wrappedValue: SteppIRDevice(settingsStore: store))
        _k4dDevice = StateObject(wrappedValue: ElecraftK4Device(settingsStore: store))
        _kpaDevice = StateObject(wrappedValue: ElecraftKPA1500Device(settingsStore: store))
        _rotatorDevice = StateObject(wrappedValue: GHRT21Device(settingsStore: store))
    }

    // MARK: – Scene Definitions

    /// The main body of the app, defining the primary window group and settings scene.
    var body: some Scene {
        // Main application window displaying the unified dashboard view.
        WindowGroup {
            MainDashboardView(
                steppirDevice: steppirDevice,
                elecraftDevice: k4dDevice,
                kpaDevice: kpaDevice,
                rotatorDevice: rotatorDevice
            )
            .environmentObject(settingsStore)
            // Listen for changes in scene phase to disconnect devices when in background or inactive.
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background || newPhase == .inactive {
                    steppirDevice.disconnect()
                    k4dDevice.disconnect()
                    kpaDevice.disconnect()
                    rotatorDevice.disconnect()
                }
            }
        }

        // Settings window showing the tabbed configuration view for each device.
        Settings {
            DeviceSettingsView(
                steppirDevice: steppirDevice,
                elecraftDevice: k4dDevice,
                kpaDevice: kpaDevice,
                rotatorDevice: rotatorDevice
            )
            .environmentObject(settingsStore)
        }
    }
}
