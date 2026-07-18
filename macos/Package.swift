// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Aster",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Aster", targets: ["Aster"])
    ],
    targets: [
        .executableTarget(
            name: "Aster",
            path: "Sources/Aster",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Security"),
                .linkedFramework("Speech"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("WebKit")
            ]
        ),
        .testTarget(
            name: "AsterTests",
            dependencies: ["Aster"],
            path: "Tests/AsterTests"
        )
    ]
)
