// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VietMac",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "VietMacCore", targets: ["VietMacCore"]),
        .library(name: "VietMacPlatform", targets: ["VietMacPlatform"]),
        .library(name: "VietMacShell", targets: ["VietMacShell"]),
        .executable(name: "VietMacApp", targets: ["VietMacApp"]),
        .executable(name: "vietmac-replay", targets: ["VietMacReplay"]),
        .executable(name: "vietmac-bench", targets: ["VietMacBench"]),
        .executable(name: "VietMacDriver", targets: ["VietMacDriver"]),
    ],
    targets: [
        .target(name: "VietMacCore"),
        .target(name: "VietMacPlatform", dependencies: ["VietMacCore"]),
        // Testable shell logic: status-to-copy mapping, setup steps, and string tables. No AppKit.
        .target(name: "VietMacShell", dependencies: ["VietMacPlatform"],
                resources: [.copy("Resources/Localizable.xcstrings")]),
        .executableTarget(
            name: "VietMacApp",
            dependencies: ["VietMacPlatform", "VietMacShell"],
            path: "Apps/VietMac",
            exclude: ["Info.plist", "README.md"]
        ),
        // Test-only native key driver; it must not depend on VietMac modules.
        .target(name: "VietMacDriverKit"),
        .executableTarget(name: "VietMacDriver", dependencies: ["VietMacDriverKit"],
                          path: "Apps/VietMacDriver", exclude: ["Info.plist"]),
        .executableTarget(name: "VietMacReplay", dependencies: ["VietMacCore"]),
        .executableTarget(name: "VietMacBench", dependencies: ["VietMacCore"]),
        .testTarget(name: "VietMacCoreTests", dependencies: ["VietMacCore"]),
        .testTarget(name: "VietMacPlatformTests", dependencies: ["VietMacPlatform"]),
        .testTarget(name: "VietMacShellTests", dependencies: ["VietMacShell", "VietMacPlatform"]),
        .testTarget(name: "VietMacDriverKitTests", dependencies: ["VietMacDriverKit"]),
    ]
)
