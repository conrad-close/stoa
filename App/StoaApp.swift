import SwiftUI

/// Stoa — an open-source, native Mac browser built on WebKit.
@main
struct StoaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
    }
}
