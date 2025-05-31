//
//  AzimuthMapView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//

import SwiftUI

/// A SwiftUI view that displays a circular, resizable azimuth map image.
/// This view presents the "AzimuthMap" asset clipped to a circular shape and scaled to fill.
struct AzimuthMapView: View {
    // MARK: – View Body

    /// The view’s content and layout.
    /// - Displays the "AzimuthMap" image asset, makes it resizable, scales it to fill,
    ///   constrains it to a 200x200 frame, and clips it to a circle.
    var body: some View {
        Image("AzimuthMap")
            .resizable()
            .scaledToFill()
            .frame(width: 200, height: 200)
            .clipShape(Circle())
    }
}
