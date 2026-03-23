// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Gridflow",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "Gridflow", targets: ["GridflowApp"])
    ],
    targets: [
        .executableTarget(
            name: "GridflowApp",
            exclude: [
                "Resources/AppIcon.icon"
            ],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
