// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TaskManagerPrototype",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "TaskManagerPrototype", targets: ["TaskManagerPrototype"])
    ],
    targets: [
        .executableTarget(
            name: "TaskManagerPrototype"
        ),
    ]
)
