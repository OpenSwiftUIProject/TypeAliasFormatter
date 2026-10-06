// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TypeAliasFormatter",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "typealias-formatter", targets: ["TypeAliasFormatterCLI"])],
    dependencies: [
        .package(path: "Packages/TypeAliasFormatterCore"),
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.8.2"),
    ],
    targets: [
        .executableTarget(
            name: "TypeAliasFormatterCLI",
            dependencies: [
                .product(name: "TypeAliasFormatterCore", package: "TypeAliasFormatterCore"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "CLI/Sources"
        ),
        .testTarget(
            name: "TypeAliasFormatterCLITests",
            dependencies: ["TypeAliasFormatterCLI"],
            path: "CLI/Tests"
        ),
    ]
)
