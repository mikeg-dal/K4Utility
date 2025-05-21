//
//  K4_UtilityApp.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import SwiftUI

@main
struct K4_UtilityApp: App {
    @StateObject private var steppirDevice = SteppIRDevice()
    @StateObject private var k4dDevice = ElecraftK4Device()
    @StateObject private var kpaDevice = ElecraftKPA1500Device()

    var body: some Scene {
        WindowGroup {
            MainDashboardView(
                steppirDevice: steppirDevice,
                elecraftDevice: k4dDevice,
                kpaDevice: kpaDevice
            )
        }
        Settings {
            DeviceSettingsView(
                steppirDevice: steppirDevice,
                elecraftDevice: k4dDevice,
                kpaDevice: kpaDevice
            )
        }
    }
}
