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
            name: "TypeAliasFormatting",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "org.openswiftuiproject.openswiftui.typealiasformatter.core",
            deploymentTargets: .macOS("14.0"),
            buildableFolders: ["Sources/TypeAliasFormatting"]
        ),
        .target(
            name: "TypeAliasFormatter",
            destinations: .macOS,
            product: .app,
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
            dependencies: [.target(name: "TypeAliasFormatting")],
            settings: .settings(base: [
                "MARKETING_VERSION": "0.1.0",
                "CURRENT_PROJECT_VERSION": "1",
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                "ENABLE_APP_SANDBOX": "YES",
                "ENABLE_USER_SELECTED_FILES": "readwrite",
                "ENABLE_HARDENED_RUNTIME": "YES",
            ])
        ),
        .target(
            name: "TypeAliasFormattingTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "org.openswiftuiproject.openswiftui.typealiasformatter.tests",
            deploymentTargets: .macOS("14.0"),
            buildableFolders: ["Tests/TypeAliasFormattingTests"],
            dependencies: [.target(name: "TypeAliasFormatting")]
        ),
    ],
    schemes: [
        .scheme(
            name: "TypeAliasFormatter",
            buildAction: .buildAction(targets: ["TypeAliasFormatter"]),
            testAction: .targets(["TypeAliasFormattingTests"]),
            runAction: .runAction(configuration: .debug, executable: "TypeAliasFormatter")
        ),
        .scheme(
            name: "TypeAliasFormattingTests",
            buildAction: .buildAction(targets: ["TypeAliasFormattingTests"]),
            testAction: .targets(["TypeAliasFormattingTests"])
        ),
    ],
    additionalFiles: ["README.md", "Package.swift"],
    resourceSynthesizers: []
)
