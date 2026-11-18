// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CurrencyCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CurrencyCore", targets: ["CurrencyCore"]),
    ],
    targets: [
        // Sources are also compiled directly into the widget extension, so keep
        // everything in Sources/CurrencyCore flat and free of SPM-only tricks.
        .target(
            name: "CurrencyCore",
            path: "Sources/CurrencyCore"
        ),
        .testTarget(
            name: "CurrencyCoreTests",
            dependencies: ["CurrencyCore"],
            path: "Tests/CurrencyCoreTests"
        ),
    ]
)
