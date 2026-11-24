// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "DevCore", platforms: [.macOS(.v14)], products: [.executable(name: "DevCore", targets: ["DevCore"])], targets: [.target(name: "DevCoreCore"), .executableTarget(name: "DevCore", dependencies: ["DevCoreCore"]), .testTarget(name: "DevCoreCoreTests", dependencies: ["DevCoreCore"])])
