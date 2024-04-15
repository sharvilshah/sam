//
//  MemoryView.swift
//  sam
//
//  Created by Sharvil Shah on 4/15/24.
//

import SwiftUI

struct MemoryView: View {
    @ObservedObject var m: Monitor
    let min = 0.0
    let max = Double(ProcessInfo.processInfo.physicalMemory)
    
    var body: some View {
        let current = Double(m.memoryUsed)
        let memoryUsedFormatted = m.memoryUsed.formatted(.byteCount(style: .memory))
        let totalMemoryFormatted = ProcessInfo.processInfo.physicalMemory.formatted(.byteCount(style: .memory))
        
        VStack {
            Text("􀧖 Memory").font(.largeTitle).padding()
            
            Gauge(value: current, in: min...max) {
            } currentValueLabel: {
                Text("\(memoryUsedFormatted) of \(totalMemoryFormatted) used")
                    .foregroundColor(.black)
            } minimumValueLabel: {
                Text("")
            } maximumValueLabel: {
                Text("\(totalMemoryFormatted)")
            }
            .gaugeStyle(.linearCapacity)
            .tint(.green)
            .padding()
        }
        Divider()
            .padding()
            
        VStack {
            Text("Total Memory: \(totalMemoryFormatted)").padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

