//
//  Untitled.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/30/25.
//

import Foundation

struct DeviceSettings: Codable {
    var ipAddress: String
    var port: Int
}

struct GHRT21Settings: Codable {
    var device: DeviceSettings
    var presetNames: [String]
    var presetAzimuths: [Int]
}

struct AppSettings: Codable {
    var k4: DeviceSettings
    var kpa1500: DeviceSettings
    var steppIR: DeviceSettings
    var ghrt21: GHRT21Settings
    // add other devices here
}
