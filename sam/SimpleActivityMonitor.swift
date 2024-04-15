//
//  SimpleActivityMonitor.swift
//  sam
//
//  Created by Sharvil Shah on 4/15/24.
//

import Foundation
import Observation
import Darwin

class Monitor: ObservableObject {
    
    struct DeviceInfo {
        var serial: String?
        var uuid: String?
        var count: Int
        var buildNumber: String?
        var osVersion: String
    }
    
    struct VolumeInfo: Hashable {
        var path: String
        var total: Int
        var free: Int
        var used: Int
    }
    
    struct CPULoadSample {
        var user: Double
        var system: Double
        var idle: Double
        var nice: Double
    }

    private var timer: Timer?
    private var TIMER_INTERVAL: Double = 0.5
    private var CPU_SAMPLE_INTERVAL: UInt32 = 1
    
    // all the things that we will display in the UI
    @Published var deviceInfo = DeviceInfo(serial: "Loading", uuid: "", count: 0, osVersion: "")
    @Published var memoryUsed: Int64 = 0
    @Published var vols: [VolumeInfo] = []
    
    // cpu load usage in percentages
    @Published var userLoad = 0.0
    @Published var systemLoad = 0.0
    @Published var idleLoad = 0.0
    
    func getSerialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice") )

        guard platformExpert > 0 else {
            return nil
        }

        guard let serialNumber = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String) else {
            return nil
        }

        IOObjectRelease(platformExpert)
        return serialNumber
    }
    
    func getHardwareUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice") )

        guard platformExpert > 0 else {
            return nil
        }

        guard let uid = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String) else {
            return nil
        }

        IOObjectRelease(platformExpert)
        return uid
    }
    
    func getBuildNumber() -> String? {
        let regRoot = IORegistryGetRootEntry(kIOMainPortDefault)

        guard regRoot > 0 else {
            return nil
        }

        guard let buildNumber = (IORegistryEntryCreateCFProperty(regRoot, kOSBuildVersionKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String) else {
            return nil
        }

        IOObjectRelease(regRoot)
        return buildNumber
    }
    
    func getOsVersion() -> String {
        let osVersion = ProcessInfo().operatingSystemVersion
        return String(osVersion.majorVersion) + "." + String(osVersion.minorVersion) + "." + String(osVersion.patchVersion)
    }
    
    // take a CPU load sample at this point in time, using the Mach host APIs
    func getCPUSample() -> CPULoadSample {
        var sample = CPULoadSample(user: 0.0, system: 0.0, idle: 0.0, nice: 0.0)
        let host = mach_host_self()
        
        // from XNU documentation: https://github.com/apple-oss-distributions/xnu/blob/main/doc/observability/recount.md
        // want to target system entity, rather than individual cores (processor is mach parlance)
        //
        // if we want even more granular, we could do what recount (https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/recount.c)
        // and just use the Intel/ARM MSR performance counters (kinda like what CHUD did in the PPC era)
        
        
        let hostcount = MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        var size = mach_msg_type_number_t(hostcount)
        var cpuinfo = host_cpu_load_info()
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &cpuinfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: hostcount) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        
        // as defined in machine.h
        //    #define CPU_STATE_USER          0
        //    #define CPU_STATE_SYSTEM        1
        //    #define CPU_STATE_IDLE          2
        //    #define CPU_STATE_NICE          3

        if result == KERN_SUCCESS {
            sample.user = Double(cpuinfo.cpu_ticks.0)
            sample.system = Double(cpuinfo.cpu_ticks.1)
            sample.idle = Double(cpuinfo.cpu_ticks.2)
            sample.nice = Double(cpuinfo.cpu_ticks.3)
            
        }
        return sample
    }
    
    // take two samples calculate differentials and return (user, system, idle) load as percentages
    func getCPULoad() -> (Double, Double, Double) {
        let sample_1 = getCPUSample()
        sleep(CPU_SAMPLE_INTERVAL)
        let sample_2 = getCPUSample()
        
        let userDiff = sample_2.user - sample_1.user
        let systemDiff = sample_2.system - sample_1.system
        let idleDiff = sample_2.idle - sample_1.idle
        let niceDiff = sample_2.nice - sample_1.nice
        
        let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
        
        let user = ((userDiff + niceDiff) / totalTicks) * 100.0
        let system = (systemDiff / totalTicks) * 100.0
        let idle = (idleDiff / totalTicks) * 100.0
        return (user, system, idle)
    }
    
    func getMemoryStats() -> Int64 {
        var vmstats = vm_statistics64_data_t()
        let host = mach_host_self()
        
        // as defined in <mach/vm_statistics.h>
        // vm_statistics64
        // #define HOST_VM_INFO64_COUNT ((mach_msg_type_number_t) \
        //            (sizeof(vm_statistics64_data_t)/sizeof(integer_t)))
        //
        
        var vmcount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &vmstats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmcount)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &vmcount)
            }
        }
        
        var memoryUsed: Int64 = 0
        if result == KERN_SUCCESS {
            // used memory is: active + inactive + wired + compressed + speculative - purgeable - external
            // just how Activity Monitor computes it
            memoryUsed = Int64((vm_size_t)(vmstats.active_count + vmstats.inactive_count + vmstats.wire_count + vmstats.compressor_page_count + vmstats.speculative_count - vmstats.purgeable_count - vmstats.external_page_count) * vm_page_size)
        }
        
        return memoryUsed
    }
    
    func getMounts() -> [VolumeInfo] {
        var volumes: [VolumeInfo] = []
        let mounts = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []
        for mount in mounts {
            let volumeInfo = try! mount.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            let mountPath = mount.path(percentEncoded: false)
            let totalCapacity = volumeInfo.volumeTotalCapacity ?? 0
            let availableCapacity = volumeInfo.volumeAvailableCapacity ?? 0
            let usedCapacity = totalCapacity - availableCapacity
            volumes.append(VolumeInfo(path: mountPath, total: totalCapacity, free: availableCapacity, used: usedCapacity))
        }
        return volumes
    }
    
    init() {
        self.deviceInfo.serial = getSerialNumber()
        self.deviceInfo.uuid = getHardwareUUID()
        self.deviceInfo.osVersion = getOsVersion()
        self.deviceInfo.buildNumber = getBuildNumber()
        
        monitor()
    }
    
    func monitor() {
        timer = Timer.scheduledTimer(withTimeInterval: TIMER_INTERVAL, repeats: true) { [weak self] _ in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                
                let (user, system, idle) = getCPULoad()
                let memoryUsed = getMemoryStats()
                let vols = getMounts()
                
                DispatchQueue.main.async { [self] in
                    self.userLoad = user
                    self.systemLoad = system
                    self.idleLoad = idle
                    self.memoryUsed = memoryUsed
                    self.vols = vols
                }
            }
        }
    }
    
}
