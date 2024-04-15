//
//  ContentView.swift
//  sam
//
//  Created by Sharvil Shah on 4/15/24.
//

import SwiftUI

enum Sensor: String, CaseIterable {
    case device = "􀙗 Device Info"
    case cpu = "􀧓 CPU"
    case memory = "􀧖 Memory"
    case disk = "􀤃 Storage"
}


struct ContentView: View {
    @State private var selectedSensor: Sensor = .device
    @StateObject private var monitor = Monitor()
    
    var body: some View {
        NavigationSplitView {
            List(Sensor.allCases, id: \.self, selection: $selectedSensor) {
                sensor in Text(sensor.rawValue).font(.title).padding()
            }
        } detail: {
            switch selectedSensor {
            case .device:
                DeviceView(m: monitor)
            case .cpu:
                CPUView(m: monitor)
            case .memory:
                MemoryView(m: monitor)
            case .disk:
                DiskView(m: monitor)
            }
        }
    }
}

#Preview {
    ContentView()
}
