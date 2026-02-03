// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TaskManager",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "TaskManager", targets: ["TaskManager"])
    ],
    dependencies: [
        .package(path: "../TaskManagerUIComponents")
    ],
    targets: [
        .executableTarget(
            name: "TaskManager",
            dependencies: ["TaskManagerUIComponents"]
        )
    ]
)
