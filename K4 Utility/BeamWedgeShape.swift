//
//  BeamWedgeShape.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

/// A circular sector (wedge) shape representing an antenna's beamwidth on a polar plot.
/// Draws a wedge centered on the given heading with the specified beamwidth.
struct BeamWedgeShape: Shape {
    // MARK: – Properties

    /// Center heading angle in degrees (0 = North, clockwise positive).
    var heading: Double

    /// Total beamwidth in degrees (angular width of the wedge).
    var beamwidth: Double

    // MARK: – Shape Protocol

    /// Creates the path for the beam wedge shape within the given rectangle.
    ///
    /// - Parameter rect: The bounding rectangle in which to draw the wedge.
    /// - Returns: A `Path` representing a circular sector (wedge) with the specified heading and beamwidth.
    func path(in rect: CGRect) -> Path {
        // Calculate the center point and radius based on the rectangle size
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Convert heading and beamwidth to SwiftUI Angle, where 0° is pointing up (-90° adjustment)
        let startAngle = Angle(degrees: -90 + (heading - beamwidth / 2))
        let endAngle   = Angle(degrees: -90 + (heading + beamwidth / 2))

        var path = Path()
        // Move to center and draw arc between startAngle and endAngle
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
