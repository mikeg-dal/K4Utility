//
//  DeviceCardContainer.swift
//  K4 Utility
//
//  Created by Mike Garcia on 6/7/25.
//

import SwiftUI

/// A compact button style used throughout device dashboards (e.g., direction, control buttons).
struct CompactDeviceButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2)
            .padding(6)
            .frame(minWidth: 30)
            .background(
                isActive
                    ? Color(red: 66/255, green: 100/255, blue: 157/255)
                    : Color(red: 61/255, green: 61/255, blue: 61/255)
            )
            .foregroundColor(.white)
            .cornerRadius(2)
            .scaleEffect(configuration.isPressed ? 1.05 : 1.0)
    }
}

/// A reusable container view that provides styling and layout for individual device dashboards.
struct DeviceCardContainer<Content: View>: View {
    let title: String
    let isConnected: Bool
    let content: () -> Content
    
    init(title: String, isConnected: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.isConnected = isConnected
        self.content = content
    }
    
    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    Text(title)
                        .font(.headline)
                }
                
                VStack(alignment: .center) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(3)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary, lineWidth: 4)
            )
            .cornerRadius(8)
            .buttonStyle(CompactDeviceButtonStyle())
        }
    }
}
