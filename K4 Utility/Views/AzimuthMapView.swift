//
//  AzimuthMapView.swift
//  K4 Utility
//
//  Created by Mike Garcia on 5/21/25.
//
import SwiftUI

struct AzimuthMapView: View {
  var body: some View {
    GeometryReader { geo in
      Image("AzimuthMap")
        .resizable()
        .scaledToFit()
        .frame(width: geo.size.width, height: geo.size.width)
    }
  }
}
