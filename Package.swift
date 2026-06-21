// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NetworkSpeedTest",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NetworkTestApp", targets: ["NetworkTestApp"])
    ],
    targets: [
        .executableTarget(
            name: "NetworkTestApp",
            exclude: [
                "Resources/SimpleAppIconGenerator"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NetworkTestAppTests",
            dependencies: ["NetworkTestApp"]
        )
    ]
)
