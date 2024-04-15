//
//  CPUView.swift
//  sam
//
//  Created by Sharvil Shah on 4/15/24.
//

import SwiftUI

struct CPUView: View {
    @ObservedObject var m: Monitor
    
    let min = 0.0
    let max = 100.0
    let gradient = Gradient(colors: [.green, .orange, .red])
    var body: some View {
        VStack {
            Text("􀧓 CPU").font(.largeTitle).padding()
            
            // system load gauge
            Gauge(value: m.systemLoad, in: min...max) {
                Text("sys")
            } currentValueLabel: {
                Text("\(m.systemLoad, specifier: "%.2f")")
            }
            .gaugeStyle(.accessoryCircular)
            .scaleEffect(2)
            .tint(gradient)
            .padding()
            .frame(height: 200)
            
            // user load gauge
            Gauge(value: m.userLoad, in: min...max) {
                Text("usr")
            } currentValueLabel: {
                Text("\(m.userLoad, specifier: "%.2f")")
            }
            .gaugeStyle(.accessoryCircular)
            .scaleEffect(2)
            .tint(gradient)
            .padding()
            .frame(height: 100)
            
            // idle load gauge
            Gauge(value: m.idleLoad, in: min...max) {
                Text("idle")
            } currentValueLabel: {
                Text("\(m.idleLoad, specifier: "%.2f")")
            }
            .gaugeStyle(.accessoryCircular)
            .scaleEffect(2)
            .tint(.green)
            .padding()
            .frame(height: 200)
        }
    }

}
