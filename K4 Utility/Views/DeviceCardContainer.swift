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
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            Color(red: 37/255, green: 37/255, blue: 37/255) // fixed background
            VStack(alignment: .center, spacing: 12) {
                content()
            }
            .padding(8)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
        )
        .cornerRadius(8)
        .buttonStyle(CompactDeviceButtonStyle())
    }
}
