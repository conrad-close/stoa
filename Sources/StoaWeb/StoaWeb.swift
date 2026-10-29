import WebKit
import StoaCore

/// WebKit-facing layer: WKWebView configuration, per-profile `WKWebsiteDataStore`s,
/// content-rule-list blocking, and (later) `WKWebExtensionController` for Chrome extensions.
@MainActor
public enum StoaWeb {
    /// Returns a fresh configuration bound to the given data store.
    public static func makeConfiguration(dataStore: WKWebsiteDataStore = .default()) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        return configuration
    }
}
