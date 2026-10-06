import SwiftUI

@main
struct TypeAliasFormatterApp: App {
    var body: some Scene {
        Window("TypeAlias Formatter", id: "formatter") {
            ContentView()
        }
        .defaultSize(width: 1240, height: 800)
        .windowResizability(.contentMinSize)
    }
}
