//
//  DeviceView.swift
//  sam
//
//  Created by Sharvil Shah on 4/15/24.
//

import SwiftUI

struct DeviceView: View {
    @ObservedObject var m: Monitor
    var body: some View {
        VStack {
            Text("􀙗 Device Info").font(.largeTitle).padding()
            
            Text("Serial Number: \(m.deviceInfo.serial ?? "")")
            Text("Hardware UUID: \(m.deviceInfo.uuid ?? "")")
            Text("OS Version: macOS \(m.deviceInfo.osVersion) (\(m.deviceInfo.buildNumber ?? ""))")
        }.padding()
    }
}
