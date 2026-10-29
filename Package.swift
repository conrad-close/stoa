// swift-tools-version: 6.2
// Stoa — core and WebKit modules. The app target lives in project.yml (XcodeGen).
import PackageDescription

let package = Package(
    name: "Stoa",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "StoaCore", targets: ["StoaCore"]),
        .library(name: "StoaWeb", targets: ["StoaWeb"]),
    ],
    targets: [
        .target(name: "StoaCore"),
        .target(name: "StoaWeb", dependencies: ["StoaCore"]),
        .testTarget(name: "StoaCoreTests", dependencies: ["StoaCore"]),
        .testTarget(name: "StoaWebTests", dependencies: ["StoaWeb", "StoaCore"]),
    ]
)
