// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Gridflow",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Gridflow", targets: ["GridflowApp"])
    ],
    targets: [
        .executableTarget(
            name: "GridflowApp",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
