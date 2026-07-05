// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "qaz",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "qaz", targets: ["qaz"]),
    ],
    targets: [
        .executableTarget(
            name: "qaz",
            path: "Sources/qaz",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "qazTests",
            dependencies: ["qaz"]
        ),
    ]
)
