//
//  DeviceConfigView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import SwiftUI

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
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()

            // Top-left info panel
            VStack(alignment: .leading, spacing: 12) {
                Text("SteppIR")
                    .font(.headline)

                HStack {
                    let freq = steppirDevice.frequencyHz
                    Text(freq > 0 ? String(format: "%.3f MHz", Double(freq) / 1000.0) : "Not Connected")
                        .bold()
                }

                HStack {
                    Text("Connected:")
                    Circle()
                        .fill(steppirDevice.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                }
                
                Text("Elecraft K4D")
                    .font(.headline)

                HStack {
                    let k4Freq = elecraftDevice.frequencyHz
                    Text(k4Freq > 0 ? formatFrequency(k4Freq) : "Not Connected")
                        .bold()
                }

                HStack {
                    Text("Connected:")
                    Circle()
                        .fill(elecraftDevice.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                }

                VStack(spacing: 6) {
                    Button("Home") {
                        steppirDevice.setHome()
                    }
                    Button(steppirDevice.isTrackingEnabled ? "Auto On" : "Auto Off") {
                        steppirDevice.setAuto(enabled: !steppirDevice.isTrackingEnabled)
                    }
                    Button("Calibrate") {
                        steppirDevice.setCalibrate()
                    }
                }
                .font(.caption)
                .padding(6)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(13)
                .frame(minWidth: 70)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Centered control stack
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    // Top row of band buttons
                    HStack(spacing: 8) {
                        ForEach([(80, 3650), (60, 5125), (40, 7150), (30, 10125), (20, 14200)], id: \.0) { band in
                            let isActive = abs(steppirDevice.frequencyHz - band.1) <= 200
                            Button("\(band.0)m") {
                                steppirDevice.setFrequency(band.1)
                                steppirDevice.setDirection(steppirDevice.direction)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(minWidth: 30)
                            .font(.caption2)
                            .padding(3)
                            .background(isActive ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(13)
                        }
                    }
                    // Bottom row of band buttons
                    HStack(spacing: 8) {
                        ForEach([(17, 18125), (15, 21200), (12, 24915), (10, 28300), (6, 50300)], id: \.0) { band in
                            let isActive = abs(steppirDevice.frequencyHz - band.1) <= 200
                            Button("\(band.0)m") {
                                steppirDevice.setFrequency(band.1)
                                steppirDevice.setDirection(steppirDevice.direction)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(minWidth: 30)
                            .font(.caption2)
                            .padding(3)
                            .background(isActive ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(13)
                        }
                    }
                }

                // Direction buttons
                HStack(spacing: 8) {
                    ForEach(["Norm", "180", "BID", "3/4"], id: \.self) { dir in
                        Button(dir) {
                            let mappedDir = dir == "Norm" ? "Normal" : dir
                            steppirDevice.setDirection(mappedDir)
                        }
                        .frame(width: 50)
                        .font(.caption)
                        .padding(6)
                        .background(steppirDevice.direction == (dir == "Norm" ? "Normal" : dir) ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(13)
                    }
                }

                // Removed tuning and gear icon row; now anchored in ZStack
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.top, 30)
            // Tuning indicator anchored top-right
            VStack {
                Text("Tuning")
                    .font(.caption)
                    .padding(.bottom, 4)
                Circle()
                    .fill(steppirDevice.tuningStatus ? Color.red : Color.green)
                    .frame(width: 12, height: 12)
            }
            .padding()
            .padding(.top, 150)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // Settings gear icon anchored bottom-right
            ZStack {
                VStack {
                    Button(action: {
                        showingSettings.toggle()
                    }) {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                    }
                    .frame(width: 36, height: 36)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .sheet(isPresented: $showingSettings) {
                        DeviceConfigView(steppirDevice: steppirDevice, elecraftDevice: elecraftDevice)
                    }
                }
                .padding(.bottom, 30)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
  
    }

