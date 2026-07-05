// swift-tools-version:5.9
import PackageDescription

// SwiftPM here covers only the pure-logic core (log reading + parsing) so it can
// be unit-tested with `swift test`. The AppKit menu bar app in App/ is built
// separately by build.sh (swiftc → .app bundle) and is intentionally outside
// the package — it has no automated tests and pulls in AppKit/ServiceManagement.
let package = Package(
    name: "IOTAMonitorCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "IOTAMonitorCore"),
        .testTarget(
            name: "IOTAMonitorCoreTests",
            dependencies: ["IOTAMonitorCore"]
        ),
    ]
)
