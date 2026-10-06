// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TypeAliasFormatting",
    platforms: [.macOS(.v14)],
    products: [.library(name: "TypeAliasFormatting", targets: ["TypeAliasFormatting"])],
    targets: [
        .target(name: "TypeAliasFormatting", path: "Sources/TypeAliasFormatting"),
        .testTarget(
            name: "TypeAliasFormattingTests",
            dependencies: ["TypeAliasFormatting"],
            path: "Tests/TypeAliasFormattingTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
