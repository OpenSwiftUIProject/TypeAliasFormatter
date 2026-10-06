// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TypeAliasFormatterCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "TypeAliasFormatterCore", targets: ["TypeAliasFormatterCore"])],
    targets: [
        .target(name: "TypeAliasFormatterCore"),
        .testTarget(
            name: "TypeAliasFormatterCoreTests",
            dependencies: ["TypeAliasFormatterCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
