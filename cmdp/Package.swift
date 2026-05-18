// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cmdp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "cmdp", targets: ["cmdp"])
    ],
    targets: [
        .target(
            name: "CLibSearch",
            dependencies: [],
            path: "Sources/CLibSearch",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "cmdp",
            dependencies: ["CLibSearch"],
            linkerSettings: [
                .unsafeFlags(["-L../daemon/build", "-lsearch"])
            ]
        ),
        .testTarget(
            name: "cmdpTests",
            dependencies: ["cmdp"]
        ),
    ]
)
