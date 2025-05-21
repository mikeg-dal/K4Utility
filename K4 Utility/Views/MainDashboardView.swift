//
//  MainDashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import SwiftUI
import Combine

func formatFrequency(_ hz: Int) -> String {
    let mhz = hz / 1_000_000
    let remainder = hz % 1_000_000
    let khz = remainder / 1_000
    let hzRemainder = remainder % 1_000
    return String(format: "%d.%03d.%03d", mhz, khz, hzRemainder)
}

struct MainDashboardView: View {
    @ObservedObject var steppirDevice: SteppIRDevice
    @ObservedObject var elecraftDevice: ElecraftK4Device
    @ObservedObject var kpaDevice: ElecraftKPA1500Device
    
    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()

            // Top-left info panel
            VStack(alignment: .leading, spacing: 12) {
                SteppIRDashboardView(device: steppirDevice)
                ElecraftK4DashboardView(device: elecraftDevice)
                ElecraftKPA1500DashboardView(device: kpaDevice)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            SettingsLink {
                Image(systemName: "gearshape")
                    .imageScale(.large)
                    .frame(width: 36, height: 36)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .padding(.bottom, 30)
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .onReceive(
            elecraftDevice.$frequencyHz
                .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
        ) { newHz in
            let rawKHz = newHz / 1000
            let truncatedKHz = (rawKHz / 10) * 10
            steppirDevice.setFrequency(truncatedKHz)
            steppirDevice.setDirection(steppirDevice.direction)
        }
    }
  
    }
