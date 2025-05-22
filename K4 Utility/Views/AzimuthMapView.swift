//
//  AzimuthMapView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//
import SwiftUI

struct AzimuthMapView: View {
    var body: some View {
        Image("AzimuthMap")
            .resizable()
            .scaledToFill()
            .frame(width: 200, height: 200)
            .clipShape(Circle())
    }
}
