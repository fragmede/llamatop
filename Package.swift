// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LlamaTop",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "llamatop", targets: ["LlamaTop"]),
        .library(name: "LlamaTopCore", targets: ["LlamaTopCore"]),
    ],
    targets: [
        .target(
            name: "LlamaTopCore",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(name: "LlamaTop", dependencies: ["LlamaTopCore"]),
        .testTarget(name: "LlamaTopCoreTests", dependencies: ["LlamaTopCore"]),
    ]
)
