//
//  K4_UtilityApp.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import SwiftUI

@main
struct K4_UtilityApp: App {
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var steppirDevice: SteppIRDevice
    @StateObject private var k4dDevice: ElecraftK4Device
    @StateObject private var kpaDevice: ElecraftKPA1500Device
    @StateObject private var rotatorDevice: GHRT21Device
    
    init() {
        let store = SettingsStore()
        _settingsStore = StateObject(wrappedValue: store)
        _steppirDevice = StateObject(wrappedValue: SteppIRDevice(settingsStore: store))
        _k4dDevice = StateObject(wrappedValue: ElecraftK4Device(settingsStore: store))
        _kpaDevice = StateObject(wrappedValue: ElecraftKPA1500Device(settingsStore: store))
        _rotatorDevice = StateObject(wrappedValue: GHRT21Device(settingsStore: store))
    }
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainDashboardView(
                steppirDevice: steppirDevice,
                elecraftDevice: k4dDevice,
                kpaDevice: kpaDevice,
                rotatorDevice: rotatorDevice
            )
            .environmentObject(settingsStore)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background || newPhase == .inactive {
                    steppirDevice.disconnect()
                    k4dDevice.disconnect()
                    kpaDevice.disconnect()
                    rotatorDevice.disconnect()
                }
            }
        }
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
