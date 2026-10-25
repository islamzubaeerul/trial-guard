// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrialGuardCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TrialGuardCore", targets: ["TrialGuardCore"]),
        .executable(name: "tgparse", targets: ["tgparse"]),
    ],
    targets: [
        .target(
            name: "TrialGuardCore",
            resources: [.copy("Resources/services.json")]
        ),
        .target(name: "TrialGuardFixtures", dependencies: ["TrialGuardCore"]),
        .executableTarget(name: "tgparse", dependencies: ["TrialGuardCore", "TrialGuardFixtures"]),
        .testTarget(name: "TrialGuardCoreTests", dependencies: ["TrialGuardCore", "TrialGuardFixtures"]),
    ]
)
