// swift-tools-version:5.7
import PackageDescription

// Privileged root daemon: com.offbet.helper
// Registered via SMAppService (macOS 13+). Does the system-level work the
// Electron shell can't: loopback DNS resolver, pf anti-VPN, browser policies,
// DNS pinning + watchdog, heartbeat, PIN, IPC server.
let package = Package(
    name: "OffbetHelper",
    platforms: [.macOS(.v12)],
    dependencies: [
        // Shared matcher (exact + suffix-walk + tokens + allowlist), also used by iOS.
        .package(path: "../shared")
    ],
    targets: [
        .executableTarget(
            name: "OffbetHelper",
            dependencies: [.product(name: "OffbetMatcher", package: "shared")],
            path: "Sources/OffbetHelper"
        )
    ]
)
