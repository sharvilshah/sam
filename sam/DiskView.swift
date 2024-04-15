//
//  DiskView.swift
//  sam
//
//  Created by Sharvil Shah on 4/15/24.
//

import SwiftUI
import Charts

struct DiskView: View {
    @ObservedObject var m: Monitor
    var body: some View {
        
        VStack {
            Text("􀤃 Volumes").font(.largeTitle).padding()
            ForEach(m.vols, id: \.self) { volume in
                Chart {
                    BarMark (
                        x: .value("used", volume.used),
                        y: .value("path", volume.path)
                    )
                    .foregroundStyle(.orange)
                    .cornerRadius(20)
                    BarMark (
                        x: .value("used", volume.free),
                        y: .value("path", volume.path)
                    )
                    .foregroundStyle(.gray)
                    .cornerRadius(15)
                }.chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 1))
                }
                .chartYAxis(.hidden)
                .chartForegroundStyleScale([
                    "Used": Color(.orange),
                    "Available": Color(.gray)
                ])
                .frame(height: 100)
                .padding()
                
                Text("Volume: \(volume.path)").font(.headline)
                Text("\(volume.used.formatted(.byteCount(style: .file))) of \(volume.total.formatted(.byteCount(style: .file))) used")
                Text("\(volume.free.formatted(.byteCount(style: .file))) available")
                Divider()
            }
        }
    }
}
