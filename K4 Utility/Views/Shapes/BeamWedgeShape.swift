//
// BeamWedgeShape.swift
// K4 Utility
//
// Created by Mike Garcia on 5/21/25.

import SwiftUI

/// A circular sector (wedge) shape representing antenna beamwidth
struct BeamWedgeShape: Shape {
    /// Center heading angle in degrees (0 = North, clockwise positive)
    var heading: Double
    /// Total beamwidth in degrees
    var beamwidth: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Start and end angles: convert heading so 0° = top (-90° in SwiftUI)
        let startAngle = Angle(degrees: -90 + (heading - beamwidth / 2))
        let endAngle   = Angle(degrees: -90 + (heading + beamwidth / 2))

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

