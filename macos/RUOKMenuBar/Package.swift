// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RUOKMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "RUOKMenuBar", targets: ["RUOKMenuBar"])
    ],
    targets: [
        .executableTarget(name: "RUOKMenuBar"),
        .testTarget(name: "RUOKMenuBarTests", dependencies: ["RUOKMenuBar"])
    ]
)
