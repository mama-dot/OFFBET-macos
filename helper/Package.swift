// swift-tools-version:5.7
import PackageDescription

// Privileged root daemon: com.offbet.helper
// Registered via SMAppService (macOS 13+). Does the system-level work the
// Electron shell can't: loopback DNS resolver, pf anti-VPN, browser policies,
// DNS pinning + watchdog, heartbeat, PIN, IPC server.
//
// Layout: the logic lives in the OffbetHelperCore *library* (unit-testable);
// the OffbetHelper *executable* is a thin entry that calls OffbetDaemon.run().
let package = Package(
    name: "OffbetHelper",
    platforms: [.macOS(.v12)],
    dependencies: [
        // Shared matcher (exact + suffix-walk + tokens + allowlist), also used by iOS.
        .package(path: "../shared")
    ],
    targets: [
        .target(
            name: "OffbetHelperCore",
            dependencies: [.product(name: "OffbetMatcher", package: "shared")],
            path: "Sources/OffbetHelperCore"
        ),
        .executableTarget(
            name: "OffbetHelper",
            dependencies: ["OffbetHelperCore"],
            path: "Sources/OffbetHelper"
        ),
        .testTarget(
            name: "OffbetHelperCoreTests",
            dependencies: ["OffbetHelperCore", .product(name: "OffbetMatcher", package: "shared")],
            path: "Tests/OffbetHelperCoreTests"
        ),
    ]
)
