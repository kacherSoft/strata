// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TaskManagerUIComponents",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "TaskManagerUIComponents",
            targets: ["TaskManagerUIComponents"]
        )
    ],
    targets: [
        .target(
            name: "TaskManagerUIComponents"
        )
    ]
)
