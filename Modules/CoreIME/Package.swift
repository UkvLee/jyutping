// swift-tools-version: 6.3

import PackageDescription

let package = Package(
        name: "CoreIME",
        platforms: [.iOS(.v16), .macOS(.v13)],
        products: [
                .library(
                        name: "CoreIME",
                        targets: ["CoreIME"]
                ),
                .executable(
                        name: "CoreIMEBenchmarks",
                        targets: ["CoreIMEBenchmarks"]
                )
        ],
        dependencies: [
                .package(path: "../CommonExtensions")
        ],
        targets: [
                .target(
                        name: "CoreIME",
                        dependencies: [
                                .product(name: "CommonExtensions", package: "CommonExtensions")
                        ],
                        resources: [.process("Resources")]
                ),
                .testTarget(
                        name: "CoreIMETests",
                        dependencies: ["CoreIME"]
                ),
                .executableTarget(
                        name: "CoreIMEBenchmarks",
                        dependencies: ["CoreIME"]
                )
        ],
        swiftLanguageModes: [.v6]
)
