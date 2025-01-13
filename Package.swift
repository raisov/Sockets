// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Sockets",
    platforms: [.macOS(.v11), .iOS(.v13)],
    products: [
        .library(
            name: "Sockets",
            targets: ["Sockets", "AddressFamily", "IPProtocol", "SocketType"]),
    ],
    targets: [
        .target(name: "AddressFamily"),
        .target(name: "IPProtocol"),
        .target(name: "SocketType"),
        .target(name: "Sockets", dependencies: ["AddressFamily", "IPProtocol", "SocketType"]),
    ]
)
