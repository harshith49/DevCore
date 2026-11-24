import Foundation

public struct ListeningPort: Identifiable, Sendable, Equatable {
    public var id: String { "\(pid):\(endpoint)" }
    public let process: String
    public let pid: Int
    public let endpoint: String
    public var port: Int? { endpoint.split(separator: ":").last.flatMap { Int($0) } }
}

public enum PortInspector {
    public static func parse(_ output: String) -> [ListeningPort] {
        var pid: Int?
        var command = ""
        var ports: [ListeningPort] = []
        for line in output.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p": pid = Int(value); command = ""
            case "c": command = value
            case "n":
                if let pid, !command.isEmpty, let port = value.split(separator: ":").last.flatMap({ Int($0) }), (1...65535).contains(port) {
                    let entry = ListeningPort(process: command, pid: pid, endpoint: value)
                    if !ports.contains(where: { $0.id == entry.id }) { ports.append(entry) }
                }
            default: break
            }
        }
        return ports.sorted { ($0.port ?? 0, $0.pid) < ($1.port ?? 0, $1.pid) }
    }

    public static func inspect() throws -> [ListeningPort] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        // lsof returns 1 when no visible listeners exist.
        guard process.terminationStatus == 0 || (process.terminationStatus == 1 && data.isEmpty) else {
            throw NSError(domain: "DevCore.Ports", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Port inspection failed. Check that /usr/sbin/lsof is available."])
        }
        return parse(String(decoding: data, as: UTF8.self))
    }
}
