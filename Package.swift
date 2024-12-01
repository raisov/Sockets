// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Sockets",
    platforms: [.macOS(.v11), .iOS(.v13)],
    products: [
        .library(
            name: "Sockets",
            targets: ["Sockets", "Definitions"]),
    ],
    targets: [
        .target(name: "Definitions"),
        .target(name: "Sockets", dependencies: ["Definitions"]),
    ]
)
