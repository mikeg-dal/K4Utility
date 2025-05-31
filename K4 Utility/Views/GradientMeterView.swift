//
//  GradientMeterView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/20/25.
//

import SwiftUI

/// A horizontal gradient meter that visually represents a value within a range.
/// The filled portion displays a color gradient from blue → green → yellow → red,
/// based on the percentage of `value` between `minValue` and `maxValue`.
struct GradientMeterView: View {
    // MARK: – Meter Configuration
    
    /// The current value to display on the meter.
    var value: Double

    /// The minimum value of the meter's range. Defaults to 0.
    var minValue: Double = 0

    /// The maximum value of the meter's range. Defaults to 100.
    var maxValue: Double = 100

    // MARK: – View Body
    
    /// The view’s content, which includes a gray background and a colored gradient
    /// rectangle whose width corresponds to the normalized `value`.
    var body: some View {
        GeometryReader { geo in
            // Calculate normalized percentage between 0 and 1
            let pct = max(0, min(1, (value - minValue) / (maxValue - minValue)))

            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                // Filled portion with a color gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.green, Color.yellow, Color.red]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(pct))
            }
        }
        // Fixed height for the meter
        .frame(height: 16)
    }
}

#if DEBUG
struct GradientMeterView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            GradientMeterView(value: 200, minValue: 0, maxValue: 1100)
                .frame(width: 200)
            GradientMeterView(value: 800, minValue: 0, maxValue: 1100)
                .frame(width: 200)
            GradientMeterView(value: 1500, minValue: 0, maxValue: 1100)
                .frame(width: 200)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
