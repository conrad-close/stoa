import WebKit
import StoaCore

/// WebKit-facing layer: per-profile data stores, content-rule-list blocking,
/// tab-bound web views, and (later) `WKWebExtensionController` for Chrome extensions.
@MainActor
public enum StoaWeb {
    /// The persistent website data store for a profile. WebKit keys stores by UUID,
    /// so each profile's cookies, storage, and sign-ins live apart and die with it.
    public static func dataStore(for profileID: UUID) -> WKWebsiteDataStore {
        WKWebsiteDataStore(forIdentifier: profileID)
    }

    /// Removes a profile's website data entirely. Call when the profile is deleted.
    public static func removeDataStore(for profileID: UUID) async throws {
        try await WKWebsiteDataStore.remove(forIdentifier: profileID)
    }

    /// A configuration for a tab browsing as the given profile.
    public static func makeConfiguration(profileID: UUID?, incognito: Bool = false) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        if incognito {
            configuration.websiteDataStore = .nonPersistent()
        } else if let profileID {
            configuration.websiteDataStore = dataStore(for: profileID)
        } else {
            configuration.websiteDataStore = .default()
        }
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsAirPlayForMediaPlayback = true
        return configuration
    }
}
