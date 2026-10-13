// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SonKey",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SonKeyCore", targets: ["SonKeyCore"]),
        .library(name: "SonKeyMac", targets: ["SonKeyMac"]),
        .executable(name: "SonKeyApp", targets: ["SonKeyApp"]),
        .executable(name: "sonkey-replay", targets: ["SonKeyReplay"]),
        .executable(name: "sonkey-bench", targets: ["SonKeyBench"]),
    ],
    targets: [
        .target(name: "SonKeyCore"),
        .target(name: "SonKeyMac", dependencies: ["SonKeyCore"]),
        .executableTarget(
            name: "SonKeyApp",
            dependencies: ["SonKeyMac"],
            path: "Apps/SonKey",
            exclude: ["Info.plist", "README.md"]
        ),
        .executableTarget(name: "SonKeyReplay", dependencies: ["SonKeyCore"]),
        .executableTarget(name: "SonKeyBench", dependencies: ["SonKeyCore"]),
        .testTarget(name: "SonKeyCoreTests", dependencies: ["SonKeyCore"]),
    ]
)
