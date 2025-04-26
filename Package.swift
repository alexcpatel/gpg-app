// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "GPGApp",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "GPGApp", targets: ["GPGApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GPGApp",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-experimental-concurrency"])
            ]
        )
    ]
) 
