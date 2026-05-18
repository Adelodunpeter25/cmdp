// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cmdp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "cmdp", targets: ["cmdp"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.1.0")
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
            dependencies: [
                "CLibSearch",
                .product(name: "HotKey", package: "HotKey")
            ],
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
