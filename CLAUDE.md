# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Recent Major Updates (January 2025)

**TCP Connection Modernization**: The entire TCP connection architecture was modernized from blocking semaphore-based connections to async/await patterns. Key changes:

- **TCPClient.swift**: Complete rewrite with async/await, exponential backoff retry, TCP optimizations, and Swift 6 concurrency compliance via custom `AtomicBool` class
- **All Device Classes**: Updated to use new async connection patterns while preserving all existing functionality
- **Critical Preservation**: SteppIR-K4 frequency synchronization logic was carefully maintained during modernization
- **App Integration**: Updated K4_UtilityApp.swift to handle async device connections on startup

**Before Making Connection Changes**: Always preserve the K4-SteppIR frequency synchronization relationship as it's critical for antenna tuning functionality.

## Build and Development Commands

This is a macOS Swift/SwiftUI application built with Xcode. 

**Build Commands:**
- `xcodebuild -project "K4 Utility.xcodeproj" -scheme "K4 Utility" -configuration Debug build` - Build debug version
- `xcodebuild -project "K4 Utility.xcodeproj" -scheme "K4 Utility" -configuration Release build` - Build release version

**Test Commands:**
- `xcodebuild -project "K4 Utility.xcodeproj" -scheme "K4 Utility" -destination "platform=macOS" test` - Run unit tests
- `xcodebuild -project "K4 Utility.xcodeproj" -scheme "K4 UtilityUITests" -destination "platform=macOS" test` - Run UI tests

**Development:**
- Open `K4 Utility.xcodeproj` in Xcode for development
- The app runs on macOS 15.0+ only
- Uses Swift 5.0 and SwiftUI framework

## Architecture Overview

K4 Utility is a macOS application for managing amateur radio equipment including:
- Elecraft K4 transceiver 
- Elecraft KPA-1500 amplifier
- SteppIR antenna controller
- GreenHeron GHRT21 rotator

### Core Architecture

**Application Structure:**
- `K4_UtilityApp.swift` - Main app entry point that instantiates all devices and manages app lifecycle
- `MainDashboardView.swift` - Primary UI that displays enabled device dashboards in a scrollable layout

**Device Management Pattern:**
Each supported device follows a consistent pattern:
- Device class (e.g., `ElecraftK4Device`) - TCP client wrapper with `@Published` properties for SwiftUI binding
- Dashboard view (e.g., `ElecraftK4DashboardView`) - SwiftUI view for device-specific UI
- Config view (e.g., `ElecraftK4ConfigView`) - Settings interface for device configuration

**Key Components:**
- `TCPClient` (`Connections/TCPClient.swift`) - Modern async/await TCP networking layer with automatic retry
- `SettingsStore` (`Utilities/SettingsStore.swift`) - Centralized settings persistence using @AppStorage
- `AppSettings` (`Utilities/AppSettings.swift`) - Settings data structures

**Device Dependencies:**
- SteppIR device requires K4 device reference for frequency coordination (CRITICAL - preserved in modernization)
- GHRT21 rotator can work with SteppIR for antenna rotation

### Modern Connection Architecture (Updated January 2025)

**TCP Connection Handling:**
The application uses a modernized async/await TCP architecture implemented in January 2025:

- **Async/Await Pattern**: All connections use modern Swift concurrency, eliminating blocking UI
- **Automatic Retry Logic**: Exponential backoff retry (up to 5 attempts) with delays capped at 30 seconds
- **Thread-Safe State Management**: Custom `AtomicBool` class ensures Swift 6 concurrency compliance
- **Connection States**: Each device tracks detailed states (disconnected, connecting, connected, reconnecting, failed)
- **TCP Optimizations**: Enabled keepalive, nodelay, and proper timeout handling via Network.framework

**TCPClient Features:**
```swift
class TCPClient {
    enum TCPError: LocalizedError // User-friendly error messages
    enum ConnectionState // Detailed connection feedback
    
    // Async connection with retry
    func connect(host: String, port: UInt16, timeout: TimeInterval, maxRetries: Int) async throws -> Bool
    
    // Thread-safe callbacks
    var onReceive: ((Data) -> Void)?
    var onDisconnect: (() -> Void)?
    var onStateChange: ((ConnectionState) -> Void)?
}
```

**Device Connection Pattern:**
Each device class implements:
```swift
enum DeviceConnectionState: Equatable {
    case disconnected, connecting, connected, reconnecting, failed(String)
}

@Published var connectionState: DeviceConnectionState = .disconnected
@Published var isConnected: Bool = false // Legacy compatibility
@Published var connectionError: String?

func connect() // Launches async connection
private func performConnection() async // Actual async implementation
private func handleConnectionFailure(_ message: String) // Error handling with retry
private func scheduleReconnection() // Automatic reconnection with backoff
```

**Connection State Management:**
- All state updates happen on @MainActor for UI thread safety
- Automatic reconnection for unexpected disconnections (not manual disconnects)
- Connection state drives UI indicators and error messages
- Polling timers automatically start/stop based on connection state

### Communication Protocol

All devices communicate via ASCII commands over TCP/IP:
- Commands are typically terminated with semicolon (`;`) 
- Responses are parsed in device-specific `parseLine()` methods
- Each device maintains a polling timer for periodic status updates (paused during disconnection)
- Connection state is managed through `@Published` properties for reactive UI updates
- **Critical**: SteppIR-K4 frequency synchronization uses debounced Combine publishers with 500ms delay

### UI Architecture

- Uses SwiftUI with dark theme (`Color(.controlBackgroundColor).brightness(-0.05)`)
- Device dashboards are conditionally displayed based on `settingsStore.settings.<device>.isEnabled`
- Settings accessible through standard macOS Settings scene
- Responsive layout using `GeometryReader` and `ScrollView`

### Project Structure

```
K4 Utility/
├── Connections/TCPClient.swift      # Shared networking
├── Devices/                         # Device-specific implementations
│   ├── ElecraftK4/                 # K4 transceiver
│   ├── ElecraftKPA1500/            # KPA-1500 amplifier  
│   ├── SteppIR/                    # Antenna controller
│   └── GreenHeron/                 # GHRT21 rotator
├── Views/                          # Shared UI components
├── Utilities/                      # Settings and utilities
└── Assets.xcassets/               # App resources
```

### Development Notes

**Connection Architecture:**
- All device classes use async/await with Combine framework for `@Published` properties
- Connection management is non-blocking - UI remains responsive during connection attempts
- Each device has individual connection state tracking and automatic retry logic
- Settings automatically persist through `SettingsStore` using `@AppStorage`
- Debug logging can be enabled per device through `debugEnabled` property
- App lifecycle manages device connections (auto-connect on launch if enabled, disconnect on termination)
- Uses macOS-specific features like `Settings` scene and `NSApplication.willTerminateNotification`

**Critical Implementation Details:**
- **SteppIR-K4 Frequency Sync**: The SteppIR device subscribes to K4 frequency changes using a debounced Combine publisher (500ms delay) to prevent flooding. This is essential for proper antenna tuning coordination.
- **Thread Safety**: All device state updates use @MainActor isolation or DispatchQueue.main.async to ensure UI thread safety
- **TCP Optimizations**: Network.framework connections use `enableKeepalive = true`, `noDelay = true`, and proper timeout handling
- **Error Recovery**: Connection failures trigger exponential backoff retry with user-friendly error messages via `TCPError.localizedDescription`

**Build Requirements:**
- **Xcode 16.3 or newer** (required for Swift 6.2+ concurrency features)
- **Swift 6.2 or newer** with full concurrency support and @MainActor isolation
- macOS 15.0+ deployment target
- Network.framework for TCP connections
- SwiftUI for user interface

**Swift 6.2+ Concurrency Requirements:**
- All device classes must use `@MainActor` isolation for ObservableObject compliance
- Async method calls to @MainActor isolated methods require `await` keyword
- Timer callbacks and closures must properly handle actor isolation
- Use `Task { await ... }` for calling async methods from non-async contexts

**Troubleshooting:**
- If seeing Swift 6 concurrency warnings, ensure all captured variables in closures use proper thread-safe access patterns
- Connection issues often relate to network accessibility - check IP addresses and port availability
- SteppIR frequency sync issues typically indicate K4 device connection problems
- Use device `debugEnabled = true` for detailed TCP communication logging

**Testing Recommendations:**
- Verify K4-SteppIR frequency synchronization after any connection changes
- Test automatic reconnection by temporarily disconnecting network
- Verify connection state UI updates reflect actual device connectivity
- Test app launch with auto-connect enabled/disabled