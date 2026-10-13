// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VietMac",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "VietMacCore", targets: ["VietMacCore"]),
        .library(name: "VietMacPlatform", targets: ["VietMacPlatform"]),
        .executable(name: "VietMacApp", targets: ["VietMacApp"]),
        .executable(name: "vietmac-replay", targets: ["VietMacReplay"]),
        .executable(name: "vietmac-bench", targets: ["VietMacBench"]),
    ],
    targets: [
        .target(name: "VietMacCore"),
        .target(name: "VietMacPlatform", dependencies: ["VietMacCore"]),
        .executableTarget(
            name: "VietMacApp",
            dependencies: ["VietMacPlatform"],
            path: "Apps/VietMac",
            exclude: ["Info.plist", "README.md"]
        ),
        .executableTarget(name: "VietMacReplay", dependencies: ["VietMacCore"]),
        .executableTarget(name: "VietMacBench", dependencies: ["VietMacCore"]),
        .testTarget(name: "VietMacCoreTests", dependencies: ["VietMacCore"]),
        .testTarget(name: "VietMacPlatformTests", dependencies: ["VietMacPlatform"]),
    ]
)
