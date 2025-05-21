//
//  GradientMeterView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/20/25.
//

// GradientMeterView.swift
// Displays a horizontal meter with green→yellow→red gradient based on value

import SwiftUI

struct GradientMeterView: View {
    var value: Double
    var minValue: Double = 0
    var maxValue: Double = 100

    var body: some View {
        GeometryReader { geo in
            let pct = max(0, min(1, (value - minValue) / (maxValue - minValue)))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.yellow, Color.red]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(pct))
            }
        }
        .frame(height: 16)
    }
}

#if DEBUG
struct GradientMeterView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            GradientMeterView(value: 200, minValue: 0, maxValue: 1500)
                .frame(width: 200)
            GradientMeterView(value: 800, minValue: 0, maxValue: 1500)
                .frame(width: 200)
            GradientMeterView(value: 1500, minValue: 0, maxValue: 1500)
                .frame(width: 200)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
