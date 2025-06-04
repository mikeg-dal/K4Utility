//
//  AppSettings.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/30/25.
//

import Foundation

/// Represents the IP address and port for a generic device connection.
struct DeviceSettings: Codable {
    /// The device’s IP address as a string (e.g., "192.168.1.10").
    var ipAddress: String

    /// The TCP port number for the device (e.g., 9200).
    var port: Int
}

/// Holds configuration and preset information specifically for the GHRT21 rotator.
/// Includes nested device connection settings and user-defined presets.
struct GHRT21Settings: Codable {
    // MARK: – Connection Info

    /// Connection settings (IP address and port) for the GHRT21 rotator.
    var device: DeviceSettings

    // MARK: – User Presets

    /// An array of user-defined preset names (e.g., ["Home", "EU", ...]).
    var presetNames: [String]

    /// An array of user-defined azimuth values (0–359) corresponding to `presetNames`.
    var presetAzimuths: [Int]
}

/// The top-level application settings container, including configuration for all devices.
/// Conforms to `Codable` for easy JSON encoding/decoding to persistent storage.
struct AppSettings: Codable {
    // MARK: – Elecraft K4 Transceiver Settings

    /// Connection settings for the Elecraft K4 transceiver.
    var k4: DeviceSettings

    // MARK: – Elecraft KPA-1500 Amplifier Settings

    /// Connection settings for the Elecraft KPA-1500 amplifier.
    var kpa1500: DeviceSettings

    // MARK: – SteppIR Antenna Controller Settings

    /// Connection settings for the SteppIR antenna controller.
    var steppIR: DeviceSettings

    // MARK: – GreenHeron RT-21 Rotator Settings

    /// Configuration and preset settings for the GHRT21 rotator.
    var ghrt21: GHRT21Settings

    // MARK: – Future Device Settings

    /// Add properties for additional device settings as needed.
    // var newDevice: DeviceSettings
}
