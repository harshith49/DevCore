import XCTest
@testable import DevCoreCore

final class DevCoreCoreTests: XCTestCase {
    func testStructuredLsofParsing() {
        let rows = PortInspector.parse("p42\ncNode server\nf10\nn127.0.0.1:3000\nn127.0.0.1:3000\np99\ncpostgres\nn[::1]:5432\npbad\ncinvalid\nn*:80\np100\ncnoise\nn*:99999\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].pid, 42)
        XCTAssertEqual(rows[0].process, "Node server")
        XCTAssertEqual(rows[1].port, 5432)
        XCTAssertTrue(PortInspector.parse("").isEmpty)
    }
    func testRealSystemSample() throws {
        let monitor = SystemMonitor()
        let first = try monitor.sample()
        XCTAssertNil(first.cpu)
        XCTAssertGreaterThan(first.memoryTotal, 0)
        XCTAssertGreaterThan(first.storageTotal, 0)
        XCTAssertGreaterThanOrEqual(first.storageFree, 0)
        Thread.sleep(forTimeInterval: 0.05)
        let second = try monitor.sample()
        XCTAssertNotNil(second.cpu)
        XCTAssertTrue((0...1).contains(second.cpu ?? -1))
    }
    func testRealPortInspection() throws {
        for row in try PortInspector.inspect() {
            XCTAssertGreaterThan(row.pid, 0)
            XCTAssertTrue((1...65535).contains(row.port ?? 0))
        }
    }
}
