import ProjectDescription

let project = Project(
    name: "TypeAliasFormatter",
    organizationName: "OpenSwiftUI Project",
    options: .options(automaticSchemesOptions: .disabled),
    settings: .settings(base: [
        "SWIFT_VERSION": "6.0",
        "MACOSX_DEPLOYMENT_TARGET": "14.0",
        "CODE_SIGN_IDENTITY": "-",
        "CODE_SIGN_STYLE": "Automatic",
    ]),
    targets: [
        .target(
            name: "TypeAliasFormatterApp",
            destinations: .macOS,
            product: .app,
            productName: "TypeAliasFormatter",
            bundleId: "org.openswiftuiproject.openswiftui.typealiasformatter",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "TypeAlias Formatter",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "LSApplicationCategoryType": "public.app-category.developer-tools",
                "NSHumanReadableCopyright": "Copyright © 2026 OpenSwiftUI Project",
            ]),
            buildableFolders: ["App/Sources", "App/Resources"],
            dependencies: [.external(name: "TypeAliasFormatterCore")],
            settings: .settings(base: [
                "MARKETING_VERSION": "0.2.0",
                "CURRENT_PROJECT_VERSION": "1",
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                "ENABLE_APP_SANDBOX": "YES",
                "ENABLE_USER_SELECTED_FILES": "readwrite",
                "ENABLE_HARDENED_RUNTIME": "YES",
            ])
        ),
        .target(
            name: "TypeAliasFormatterCLI",
            destinations: .macOS,
            product: .commandLineTool,
            productName: "typealias-formatter",
            bundleId: "org.openswiftuiproject.openswiftui.typealiasformatter.cli",
            deploymentTargets: .macOS("14.0"),
            infoPlist: nil,
            buildableFolders: ["CLI/Sources"],
            dependencies: [
                .external(name: "TypeAliasFormatterCore"),
                .external(name: "ArgumentParser"),
            ],
            settings: .settings(base: ["PRODUCT_MODULE_NAME": "TypeAliasFormatterCLI"])
        ),
    ],
    schemes: [
        .scheme(
            name: "TypeAliasFormatterApp",
            buildAction: .buildAction(targets: ["TypeAliasFormatterApp"]),
            runAction: .runAction(configuration: .debug, executable: "TypeAliasFormatterApp")
        ),
        .scheme(
            name: "TypeAliasFormatterCLI",
            buildAction: .buildAction(targets: ["TypeAliasFormatterCLI"]),
            runAction: .runAction(configuration: .debug, executable: "TypeAliasFormatterCLI")
        ),
    ],
    additionalFiles: ["README.md", "Package.swift", "CLI/Tests", "Licenses", "Scripts"],
    resourceSynthesizers: []
)
