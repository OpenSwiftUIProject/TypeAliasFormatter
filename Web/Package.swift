// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TypeAliasFormatterWeb",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TypeAliasFormatterWeb", targets: ["TypeAliasFormatterWeb"])],
    dependencies: [
        .package(path: "../Packages/TypeAliasFormatterCore"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", exact: "0.57.0"),
    ],
    targets: [
        .executableTarget(
            name: "TypeAliasFormatterWeb",
            dependencies: [
                .product(name: "TypeAliasFormatterCore", package: "TypeAliasFormatterCore"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ],
            linkerSettings: [
                // Foundation encoding and graph traversal must support Core's 128-level limit.
                .unsafeFlags(["-Xlinker", "-z", "-Xlinker", "stack-size=8388608"], .when(platforms: [.wasi])),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
