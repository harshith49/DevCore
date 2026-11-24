import Foundation
import Darwin
import IOKit.ps

public struct SystemSnapshot: Sendable {
    public let cpu: Double?
    public let memoryUsed: UInt64
    public let memoryTotal: UInt64
    public let storageFree: Int64
    public let storageTotal: Int64
    public let batteryPercent: Int?
    public let batteryState: String
}

public final class SystemMonitor {
    private var previous: (UInt64, UInt64)?
    public init() {}
    public func sample() throws -> SystemSnapshot {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let cpuResult = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) }
        }
        guard cpuResult == KERN_SUCCESS else { throw MonitorError.unavailable }
        let ticks = cpuInfo.cpu_ticks
        let busy = UInt64(ticks.0) + UInt64(ticks.1) + UInt64(ticks.3)
        let total = busy + UInt64(ticks.2)
        var cpu: Double?
        if let previous, total > previous.1, busy >= previous.0 { cpu = min(1, Double(busy - previous.0) / Double(total - previous.1)) }
        previous = (busy, total)
        var vm = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let vmResult = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount) }
        }
        guard vmResult == KERN_SUCCESS else { throw MonitorError.unavailable }
        let used = (UInt64(vm.active_count) + UInt64(vm.inactive_count) + UInt64(vm.wire_count) + UInt64(vm.compressor_page_count) - min(UInt64(vm.inactive_count), UInt64(vm.purgeable_count))) * UInt64(getpagesize())
        let disk = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let battery = Self.battery()
        return SystemSnapshot(cpu: cpu, memoryUsed: used, memoryTotal: ProcessInfo.processInfo.physicalMemory, storageFree: (disk[.systemFreeSize] as? NSNumber)?.int64Value ?? 0, storageTotal: (disk[.systemSize] as? NSNumber)?.int64Value ?? 0, batteryPercent: battery.0, batteryState: battery.1)
    }
    private static func battery() -> (Int?, String) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return (nil, "Unavailable") }
        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any], d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType, let current = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            return (Int(Double(current) / Double(max) * 100), d[kIOPSPowerSourceStateKey] as? String ?? "Unknown")
        }
        return (nil, "No internal battery")
    }
    public enum MonitorError: LocalizedError { case unavailable; public var errorDescription: String? { "macOS could not provide system statistics." } }
}
