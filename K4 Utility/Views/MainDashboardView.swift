//
//  MainDashboardView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/18/25.
//

import SwiftUI

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
                HStack(alignment: .top, spacing: 12) {
                    SteppIRDashboardView(device: steppirDevice, k4Device: elecraftDevice)
                    ElecraftKPA1500DashboardView(device: kpaDevice)
                }

                ElecraftK4DashboardView(device: elecraftDevice)
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
    }
  
    }
