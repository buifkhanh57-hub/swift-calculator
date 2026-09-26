// swift-tools-version:5.9
//
// Package.swift — package manifest for `unitwise`.
//
// unitwise is a dependency-free unit-converter CLI: it deliberately uses only
// the Swift standard library and Foundation, so it builds anywhere Swift 5.9
// builds (macOS and Linux) with zero third-party packages.
//
// Layout:
//   Sources/UnitWise/       the executable target (CLI + core + categories)
//   Tests/UnitWiseTests.swift  XCTest suite + plain self-test runner
//

import PackageDescription

let package = Package(
    name: "unitwise",
    products: [
        // The CLI binary: `swift run unitwise "5 km to mi"`.
        .executable(
            name: "unitwise",
            targets: ["UnitWise"]
        )
    ],
    targets: [
        // Single executable target — all library code (Core/, Categories/)
        // lives inside it, which keeps the build graph trivial.
        .executableTarget(
            name: "UnitWise",
            path: "Sources/UnitWise"
        ),
        // XCTest suite. Since Swift 5.5 test targets may import executable
        // targets, so the tests exercise the exact binary code paths.
        // The suite also exposes `SelfTest.runAll()` which the binary itself
        // runs through `unitwise selftest` (no XCTest needed at runtime).
        .testTarget(
            name: "UnitWiseTests",
            dependencies: ["UnitWise"],
            path: "Tests"
        )
    ]
)
