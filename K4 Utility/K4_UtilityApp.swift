//
//  K4_UtilityApp.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import SwiftUI
import AppKit

/// The main application entry point for K4 Utility, handling app lifecycle, device instantiation,
/// and scene definitions for the main dashboard and device settings.
@main
struct K4_UtilityApp: App {
    // MARK: – State Objects (Persistent Across Scenes)

    /// The persistent settings store for application-wide configuration.
    @StateObject private var settingsStore: SettingsStore

    /// The Elecraft K4 transceiver device instance, shared across views.
    @StateObject private var k4dDevice: ElecraftK4Device

    /// The SteppIR antenna controller device instance, shared across views.
    @StateObject private var steppirDevice: SteppIRDevice

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
        let k4Instance = ElecraftK4Device(settingsStore: store)
        let steppirInstance = SteppIRDevice(settingsStore: store, k4Device: k4Instance)
        _settingsStore = StateObject(wrappedValue: store)
        _k4dDevice    = StateObject(wrappedValue: k4Instance)
        _steppirDevice = StateObject(wrappedValue: steppirInstance)
        _kpaDevice    = StateObject(wrappedValue: ElecraftKPA1500Device(settingsStore: store))
        _rotatorDevice = StateObject(wrappedValue: GHRT21Device(settingsStore: store))
    }

    // MARK: – Device Management Helpers

    /// Connects all enabled devices based on the settings.
    private func connectEnabledDevices() {
        Task {
            if settingsStore.settings.k4.isEnabled {
                k4dDevice.connect()
            }
            if settingsStore.settings.kpa1500.isEnabled {
                kpaDevice.connect()
            }
            if settingsStore.settings.steppIR.isEnabled {
                steppirDevice.connect()
            }
            if settingsStore.settings.ghrt21.isEnabled {
                rotatorDevice.connect()
            }
        }
    }

    /// Disconnects all devices.
    private func disconnectAllDevices() {
        // Disconnect in proper order: SteppIR first to avoid issues with K4 frequency sync
        steppirDevice.disconnect()
        k4dDevice.disconnect()
        kpaDevice.disconnect()
        rotatorDevice.disconnect()
    }

    // MARK: – Scene Definitions

    /// The main body of the app, defining the primary window group and settings scene.
    var body: some Scene {
        WindowGroup {
            MainDashboardView(
                steppirDevice: steppirDevice,
                elecraftDevice: k4dDevice,
                kpaDevice: kpaDevice,
                rotatorDevice: rotatorDevice,
                settingsStore: settingsStore
            )
            .environmentObject(settingsStore)
            .task {
                if settingsStore.settings.autoConnectEnabled {
                    connectEnabledDevices()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                disconnectAllDevices()
            }
        }
        Settings {
            DeviceSettingsView(
                steppirDevice: steppirDevice,
                elecraftDevice: k4dDevice,
                kpaDevice: kpaDevice,
                rotatorDevice: rotatorDevice,
                settingsStore: settingsStore
            )
            .environmentObject(settingsStore)
        }
        
    }
}
