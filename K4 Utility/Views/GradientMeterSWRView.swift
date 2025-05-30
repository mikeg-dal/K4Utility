//
//  GradientMeterSWRView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/20/25.
//

import SwiftUI

struct GradientMeterSWRView: View {
    /// Incoming SWR value
    var value: Double
    var minValue: Double = 0
    var maxValue: Double = 5

    /// Duration (in seconds) after the last update to reset the meter back to zero
    var noDataResetDuration: TimeInterval = 1.0

    @State private var displayedValue: Double = 0
    @State private var resetWorkItem: DispatchWorkItem?

    var body: some View {
        GeometryReader { geo in
            let pct = mappedPct(for: displayedValue)
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                // Fill capsule with dynamic gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors(for: displayedValue)),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(pct))
            }
            .onChange(of: value) {
                updateValue(to: value)
            }
            .onAppear {
                displayedValue = value
                scheduleReset()
            }
        }
        .frame(height: 16)
    }

    // MARK: - Helpers

    private func normalized(_ v: Double) -> Double {
        max(0, min(1, (v - minValue) / (maxValue - minValue)))
    }

    /// Maps SWR values so that values ≤1.5 fill 45%, 1.5–2.0 fill next 10%, and 2.0–5.0 fill next 45% (rest), above 5.0 is full.
    private func mappedPct(for v: Double) -> Double {
        // Segment 1: 1.0–1.5 → 0.00–0.45
        if v <= 1.5 {
            let raw = (v - minValue) / (1.5 - minValue) * 0.45
            return max(0, min(1, raw))
        }
        // Segment 2: 1.5–2.0 → 0.45–0.55
        else if v <= 2.0 {
            let raw = 0.45 + (v - 1.5) / (2.0 - 1.5) * 0.10
            return max(0, min(1, raw))
        }
        // Segment 3: 2.0–5.0 → 0.55–1.00
        else if v <= 5.0 {
            let raw = 0.55 + (v - 2.0) / (5.0 - 2.0) * 0.45
            return max(0, min(1, raw))
        }
        // Above 5.0: full bar
        else {
            return 1.0
        }
    }

    private func gradientColors(for v: Double) -> [Color] {
        switch v {
        case 1.0..<1.10:
            // 1.00–1.09: solid blue
            return [.blue, .blue]
        case 1.10..<1.20:
            // 1.10–1.19: blue → green
            return [.blue, .green]
        case 1.20..<1.30:
            // 1.20–1.29: blue → green → light yellow
            return [.blue, .green, .yellow.opacity(0.6)]
        case 1.30..<1.40:
            // 1.30–1.39: blue → green → yellow
            return [.blue, .green, .yellow]
        default:
            // ≥1.40: full spectrum to red
            return [.blue, .green, .yellow, .red]
        }
    }

    private func updateValue(to newValue: Double) {
        // Cancel any pending reset
        resetWorkItem?.cancel()

        // Animate to new reading
        withAnimation(.easeOut(duration: 0.2)) {
            displayedValue = newValue
        }

        // Schedule reset
        scheduleReset()
    }

    private func scheduleReset() {
        let work = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.5)) {
                displayedValue = 0
            }
        }
        resetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + noDataResetDuration, execute: work)
    }
}

#if DEBUG
struct GradientMeterSWRView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            GradientMeterSWRView(value: 1.05)
                .frame(width: 200)
            GradientMeterSWRView(value: 1.15)
                .frame(width: 200)
            GradientMeterSWRView(value: 1.25)
                .frame(width: 200)
            GradientMeterSWRView(value: 1.35)
                .frame(width: 200)
            GradientMeterSWRView(value: 2.00)
                .frame(width: 200)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
