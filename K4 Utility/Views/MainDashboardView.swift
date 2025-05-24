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
    @ObservedObject var rotatorDevice: GHRT21Device
    
    var body: some View {
        ZStack {
            Color(red: 37/255, green: 37/255, blue: 37/255)
                .ignoresSafeArea()

            // Top-left info panel
            VStack(alignment: .leading, spacing: 12) {
                SteppIRDashboardView(device: steppirDevice, k4Device: elecraftDevice)
                ElecraftKPA1500DashboardView(device: kpaDevice)
                ElecraftK4DashboardView(device: elecraftDevice)
                GHRT21DashboardView(device: rotatorDevice, steppirDevice: steppirDevice)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        }
    }
#if DEBUG
struct MainDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        MainDashboardView(
            steppirDevice: SteppIRDevice(),
            elecraftDevice: ElecraftK4Device(),
            kpaDevice: ElecraftKPA1500Device(),
            rotatorDevice: GHRT21Device()
        )
    }
}
#endif
  
    }
