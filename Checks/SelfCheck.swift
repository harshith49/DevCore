import Foundation

@main
struct SelfCheck {
    static func main() throws {
        let rows = PortInspector.parse("p42\ncNode server\nn127.0.0.1:3000\nn127.0.0.1:3000\np99\ncpostgres\nn[::1]:5432\npbad\ncinvalid\nn*:80\np100\ncnoise\nn*:99999\n")
        precondition(rows.count == 2 && rows[0].pid == 42 && rows[0].process == "Node server" && rows[1].port == 5432)
        precondition(PortInspector.parse("").isEmpty)
        let monitor = SystemMonitor()
        let first = try monitor.sample()
        precondition(first.cpu == nil && first.memoryTotal > 0 && first.storageTotal > 0)
        Thread.sleep(forTimeInterval: 0.1)
        let second = try monitor.sample()
        precondition((0...1).contains(second.cpu ?? -1))
        for row in try PortInspector.inspect() {
            precondition(row.pid > 0 && (1...65535).contains(row.port ?? 0))
        }
        print("PASS: parser, live CPU/memory/storage and lsof checks")
    }
}
