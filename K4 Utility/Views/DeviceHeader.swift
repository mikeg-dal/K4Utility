//
//  DeviceHeader.swift
//  K4 Utility
//
//  Created by Mike Garcia on 6/7/25.
//

//
//  DeviceHeader.swift
//  K4 Utility
//
//  Created by Mike Garcia on 6/7/25.
//

import SwiftUI

/// A reusable header view that shows the device name and connection status.
struct DeviceHeader: View {
    var title: String
    var isConnected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 0)
    }
}
