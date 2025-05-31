

# Article: K4Utility Overview

K4Utility is a modular SwiftUI macOS application (macOS 14+) designed to provide a unified control interface for multiple ham-radio devices over TCP/IP. By leveraging Combine and SwiftUI, K4Utility offers real-time telemetry, configuration, and control of each device in a visually cohesive dashboard. 

## Supported Devices

- **Elecraft K4 Transceiver**  
  - Sends and receives commands via ASCII over TCP.  
  - Provides frequency, power, SWR, and meter updates.  

- **Elecraft KPA-1500 Amplifier**  
  - Polls amplifier status (power output, temperature, SWR, plate voltage/current) at regular intervals.  
  - Supports toggling between Operate and Standby modes, and selecting antenna ports.  

- **SteppIR Antenna Controller**  
  - Communicates using a hex-based protocol.  
  - Publishes frequency, direction, and tuning status.  
  - Supports “Home,” “Auto‐Track,” and “Calibrate” commands.  
  - Automatically synchronizes frequency when auto‐track is disabled.  

- **GreenHeron RT-21D Rotator**  
  - Receives azimuth status and sends “go to preset” or “stop” commands.  
  - Supports up to eight user‐defined azimuth presets with names.  
  - Provides a visual azimuth map with current heading and beam wedge.  

## Project Structure

```
K4Utility/
├── App/  
│   └── K4_UtilityApp.swift         // Entry point, initializes devices and settings  
├── Devices/  
│   ├── ElecraftK4/  
│   │   ├── ElecraftK4Device.swift   // TCPClient integration, parsing, Combine publishers  
│   │   ├── ElecraftK4DashboardView.swift  
│   │   └── ElecraftK4ConfigView.swift  
│   ├── ElecraftKPA1500/  
│   │   ├── ElecraftKPA1500Device.swift  
│   │   ├── ElecraftKPA1500DashboardView.swift  
│   │   └── ElecraftKPA1500ConfigView.swift  
│   ├── SteppIR/  
│   │   ├── SteppIRDevice.swift  
│   │   ├── SteppIRDashboardView.swift  
│   │   └── SteppIRConfigView.swift  
│   └── GHRT21/  
│       ├── GHRT21Device.swift  
│       ├── GHRT21DashboardView.swift  
│       └── GHRT21ConfigView.swift  
├── Networking/  
│   └── TCPClient.swift              // Shared TCP connection wrapper  
├── Views/  
│   ├── AzimuthMapView.swift  
│   ├── BeamWedgeShape.swift  
│   └── GradientMeterView.swift  
├── Settings/  
│   ├── SettingsStore.swift          // Persistent JSON settings in Application Support  
│   ├── AppSettings.swift            // Codable container for all device settings  
│   └── DeviceSettingsView.swift     // Tab‑based UI for configuring each device  
└── Documentation/  
    └── K4UtilityDoc.docc/           // DocC catalog (Overview.md, tutorials, etc.)
```

## Installation and Setup

1. **Clone the Repository**  
   ```bash
   git clone https://github.com/your‑repo/K4Utility.git
   cd K4Utility
   ```

2. **Open in Xcode**  
   - Use Xcode 15 or later.  
   - Open `K4Utility.xcodeproj` (or workspace if multiple targets).

3. **Configure Device IP/Port**  
   - Build and run the app (⌘R).  
   - Go to **Settings ▶︎ K4Utility** from the menu bar.  
   - Select each device’s tab (“SteppIR,” “K4D,” “KPA1500,” or “GreenHeron”) and enter the correct IP address and port number for each on your LAN.  
     - Default values:  
       - K4D: 192.168.1.10:9200  
       - KPA1500: 192.168.1.11:9201  
       - SteppIR: 192.168.1.18:10001  
       - GHRT21: 192.168.1.12:4532  
   - Toggle “Connect” to establish a TCP connection. The small LED indicator will turn green when connected or red when disconnected.

4. **Save Settings**  
   - Settings are automatically saved to `~/Library/Application Support/K4Utility/settings.json`.  
   - On subsequent launches, the app will restore your last used IP addresses, ports, and presets.

## Usage

- **Main Dashboard**  
  - Displays all connected device dashboards in a dark‐themed layout.  
  - **Top Area (SteppIR)**: Shows tuning status and frequency.  
  - **Middle Row**:  
    - **Left**: KPA‑1500 metrics (power, temperature, SWR) and Operate/Standby toggle.  
    - **Right**: K4 transceiver metrics (frequency, forward/reflected power, SWR).  
  - **Bottom Area**: RT‑21 rotator visualization (azimuth map with beam wedge, preset buttons, stop control).

- **Device Dashboards**  
  - **SteppIR**:  
    - “Norm,” “180,” “BID” direction buttons.  
    - “Home,” “Auto,” and “Calibrate” commands.  
    - Band preset buttons (80m, 60m, 40m, 30m, 20m, 17m, 15m, 12m, 10m, 6m) highlight active band based on frequency.  
    - Auto‑sync from K4: when auto‑track is disabled, changing frequency on the K4 automatically updates SteppIR to the nearest 10 kHz.  
  - **KPA‑1500**:  
    - Operate/Standby toggle, antenna port selection, ATU, Reset (placeholders for future features).  
    - Forward/Reflected power, input power, SWR, temperature, plate voltage/current meters.  
  - **K4D**:  
    - Frequency big‐text display (MHz), forward/reflected power, SWR, and optional meters.  
    - Uses ASCII‐based “FA;” and “TM1;” commands to poll the transceiver.  
  - **GHRT21**:  
    - Azimuth map with a beam wedge overlay showing current heading; small overlay displays numeric heading (°).  
    - Eight user‐defined presets (N, NE, E, SE, S, SW, W, NW by default) that send “AP0<xxx>” commands.  
    - Stop button to halt movement.  

## Architecture and Code Conventions

- **SwiftUI & Combine**  
  - Each device wrapper (e.g., `ElecraftK4Device`) is an `ObservableObject` exposing `@Published` properties.  
  - Dashboards subscribe to these properties to update UI in real time.  
  - Config views bind directly to the device’s `@Published` properties for IP, port, and debug toggles.  

- **Networking**  
  - `TCPClient.swift` encapsulates a single `NWConnection` with `connect(host:port:)`, `send(_:)`, and `disconnect()` methods.  
  - Each device’s `Device.swift` file:  
    - Creates its own `TCPClient` instance.  
    - Implements parsing logic in `handleIncoming(data:)`.  
    - Parses semicolon‐terminated or hex‐terminated frames specific to each protocol.  

- **Settings Persistence**  
  - `SettingsStore.swift` monitors changes to `@Published var settings: AppSettings`.  
  - Encodes `AppSettings` via `JSONEncoder` to `~/Library/Application Support/K4Utility/settings.json`.  
  - `AppSettings.swift` contains `DeviceSettings` and `GHRT21Settings` structs (both `Codable`).  

- **UI Structure**  
  - **`MainDashboardView.swift`**: Dark background ZStack that composes all four device dashboard subviews with padding.  
  - **`DeviceSettingsView.swift`**: TabView for each device’s `ConfigView`.  
  - **Custom Views**:  
    - `AzimuthMapView` and `BeamWedgeShape` for rotator visualization.  
    - `GradientMeterView` for horizontal power meters.  

## Extending K4Utility

- **Adding a New Device**  
  1. Create a new folder under `Devices/` (e.g., `MyNewDevice/`).  
  2. Add `MyNewDeviceDevice.swift` with `ObservableObject` wrapper, parsing, and `@Published` metrics.  
  3. Create corresponding SwiftUI views:  
     - `MyNewDeviceConfigView.swift` (for IP, port, debug, presets).  
     - `MyNewDeviceDashboardView.swift` (for real-time metrics, controls).  
  4. Update `K4_UtilityApp.swift`:  
     - Add `@StateObject private var myDevice: MyNewDeviceDevice` initialized with `settingsStore`.  
     - Pass `myDevice` into `MainDashboardView` and `DeviceSettingsView`.  

- **Documentation**  
  - Add inline DocC comments (using `///`) to any public property, method, or struct.  
  - To include a new overview or tutorial, add another Markdown file under `K4UtilityDoc.docc/Articles` or `Tutorials`, starting with `# Article:` or `# Tutorial:`.

---

For more detailed API reference, switch to the Xcode Documentation viewer (⇧⌘⌥B). Happy hamming!  
