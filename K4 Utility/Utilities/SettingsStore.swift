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
        // 1. Construct the Application Support URL
        let fm = FileManager.default
        let baseDir: FileManager.SearchPathDirectory = {
            #if os(iOS)
            return .documentDirectory
            #else
            return .applicationSupportDirectory
            #endif
        }()
        let appSupport = try! fm
            .url(for: baseDir,
                 in: .userDomainMask,
                 appropriateFor: nil,
                 create: true)
            .appendingPathComponent("K4Utility", isDirectory: true)
        
        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        fileURL = appSupport.appendingPathComponent("settings.json")
        
        // 2. Load existing settings or use defaults
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data)
        {
            // Successfully decoded existing settings
            settings = loaded
        } else {
            // Provide default settings when no file exists or decoding fails
            settings = AppSettings(
                k4: DeviceSettings(ipAddress: "192.168.1.10", port: 9200),
                kpa1500: DeviceSettings(ipAddress: "192.168.1.11", port: 9201),
                steppIR: DeviceSettings(ipAddress: "192.168.1.18", port: 10001),
                ghrt21: GHRT21Settings(
                    device: DeviceSettings(ipAddress: "192.168.1.12", port: 4532),
                    presetNames: Array(repeating: "", count: 8),
                    presetAzimuths: Array(repeating: 0, count: 8)
                )
            )
        }
        
        // 3. Automatically save on any change to `settings`
        $settings
            .dropFirst() // Skip the initial value to avoid saving defaults immediately
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global())
            .sink { [weak self] new in
                guard let self = self else { return }
                if let data = try? JSONEncoder().encode(new) {
                    try? data.write(to: self.fileURL, options: [.atomic])
                }
            }
            .store(in: &cancellables)
    }
}
