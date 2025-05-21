//
// SteppIRDashboardView.swift
// K4 Utility
//
// Created by Mike Garcia on 5/21/25.
//

import SwiftUI

struct SteppIRDashboardView: View {
    @ObservedObject var device: SteppIRDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Connection status
            HStack {
                Circle()
                    .fill(device.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text("SteppIR")
                    .font(.headline)
            }

            // Frequency display
            HStack {
                let hz = device.frequencyHz
                Text(hz > 0
                     ? String(format: "%.3f MHz", Double(hz) / 1000.0)
                     : "Not Connected")
                    .bold()
            }
        }
        .padding(8)
    }
}

#if DEBUG
struct SteppIRDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        SteppIRDashboardView(device: SteppIRDevice())
    }
}
#endif
