//
//  SettingsStore.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/30/25.
//

import Foundation
import Combine

/// A persistent settings store that reads and writes application settings from a JSON file
/// in the user's Application Support directory. Automatically saves changes to disk when the
/// `settings` property is updated.
final class SettingsStore: ObservableObject {
    // MARK: – Published Properties
    
    /// The in-memory application settings. When modified, changes are automatically saved to disk.
    @Published var settings: AppSettings
    
    // MARK: – Private Properties
    
    /// The file URL where `settings.json` is stored in Application Support.
    private let fileURL: URL
    
    /// Cancellables for Combine subscriptions used to observe and save settings.
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: – Initialization
    
    /// Initializes the `SettingsStore`, creating the Application Support directory if necessary,
    /// loading existing settings from `settings.json`, or applying default settings if the file does not exist.
    /// Sets up a Combine pipeline to automatically save changes to the `settings` property.
    init() {
        // 1. Construct the Application Support URL safely
        let fm = FileManager.default
        let baseDir: FileManager.SearchPathDirectory = {
            #if os(iOS)
            return .documentDirectory
            #else
            return .applicationSupportDirectory
            #endif
        }()
        guard let baseURL = try? fm.url(for: baseDir,
                                        in: .userDomainMask,
                                        appropriateFor: nil,
                                        create: true) else {
            fatalError("Could not determine Application Support directory.")
        }
        let appSupport = baseURL.appendingPathComponent("K4Utility", isDirectory: true)
        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        fileURL = appSupport.appendingPathComponent("settings.json")

        // 2. Load existing settings or use defaults
        let loadedSettings: AppSettings
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            loadedSettings = decoded
        } else {
            loadedSettings = Self.defaultSettings()
        }
        self.settings = loadedSettings

        // 3. Automatically save on any change to `settings`
        $settings
            .dropFirst() // Skip the initial value to avoid saving defaults immediately
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global())
            .sink { [weak self] new in
                self?.saveSettings(new)
            }
            .store(in: &cancellables)
    }

    // MARK: – Private Methods

    /// Returns the default settings.
    private static func defaultSettings() -> AppSettings {
        AppSettings(
            k4: K4Settings(device: DeviceSettings(ipAddress: "192.168.1.10", port: 9200), isEnabled: true),
            k4Macros: MacroSettings(
                macroNames: Array(repeating: "", count: 3),
                macroCommands: Array(repeating: "", count: 3)
            ),
            kpa1500: KPA1500Settings(device: DeviceSettings(ipAddress: "192.168.1.9", port: 1500), isEnabled: true),
            kpa1500Macros: MacroSettings(
                macroNames: Array(repeating: "", count: 3),
                macroCommands: Array(repeating: "", count: 3)
            ),
            steppIR: SteppIRSettings(device: DeviceSettings(ipAddress: "192.168.1.18", port: 10001), isEnabled: true),
            ghrt21: GHRT21Settings(
                device: DeviceSettings(ipAddress: "192.168.1.12", port: 4532),
                presetNames: Array(repeating: "", count: 8),
                presetAzimuths: Array(repeating: 0, count: 8)
            )
        )
    }

    /// Loads settings from disk or returns the default if loading fails.
    private func loadSettings() -> AppSettings {
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return loaded
        } else {
            return Self.defaultSettings()
        }
    }

    /// Saves the provided settings to disk. Logs an error if saving fails.
    private func saveSettings(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("⚠️ Failed to write settings to disk: \(error.localizedDescription)")
        }
    }
}
