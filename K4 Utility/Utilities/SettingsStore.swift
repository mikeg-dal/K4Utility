//
//  SettingsStore.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/30/25.
//
import Foundation
import Combine

final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings
    
    private let fileURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 1. Construct the Application Support URL
        let fm = FileManager.default
        let appSupport = try! fm
            .url(for: .applicationSupportDirectory,
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
            settings = loaded
        } else {
            // provide your defaults here
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
        
        // 3. Automatically save on any change
        $settings
            .dropFirst()                // skip the initial value
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
