// swift-tools-version:5.7
import PackageDescription

// The OFFBET matcher, shared between the macOS helper and the iOS app
// (roadmap Decision 6: one Swift Package for iOS+macOS). Pure logic, no
// entitlements, fully unit-testable — the right place to port the matcher from
// Android (Kotlin) / Windows (C#).
let package = Package(
    name: "OffbetMatcher",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "OffbetMatcher", targets: ["OffbetMatcher"])
    ],
    targets: [
        .target(name: "OffbetMatcher", path: "Sources/OffbetMatcher"),
        .testTarget(name: "OffbetMatcherTests", dependencies: ["OffbetMatcher"], path: "Tests/OffbetMatcherTests")
    ]
)
