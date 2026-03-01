//
//  VerticalAccessoryGaugeStyle.swift
//  BatteryShare
//
//  Created by Jack Kroll on 2/28/26.
//


// Source - https://stackoverflow.com/a/77019032
// Posted by jrturton
// Retrieved 2026-02-28, License - CC BY-SA 4.0
import SwiftUI

struct VerticalAccessoryGaugeStyle: GaugeStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            configuration.maximumValueLabel
            GeometryReader { proxy in
                Capsule()
                    .fill(.tint)
                    .rotationEffect(.degrees(180))
                Circle()
                    .stroke(.background, style: StrokeStyle(lineWidth: 3))
                    .position(x: 5, y: proxy.size.height * (1 - configuration.value))
            }
            .frame(width: 10)
            .clipped()
            configuration.minimumValueLabel
        }
    }
}
