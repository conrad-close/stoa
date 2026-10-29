import Foundation
import SwiftData

public enum Appearance: String, Codable, CaseIterable, Sendable {
    case system, light, dark
}

public enum SearchEngine: String, Codable, CaseIterable, Sendable {
    case duckDuckGo, google, bing, kagi, startpage, ecosia, brave

    public var displayName: String {
        switch self {
        case .duckDuckGo: "DuckDuckGo"
        case .google: "Google"
        case .bing: "Bing"
        case .kagi: "Kagi"
        case .startpage: "Startpage"
        case .ecosia: "Ecosia"
        case .brave: "Brave Search"
        }
    }

    /// Query template; `%@` is replaced with the percent-encoded query.
    public var queryTemplate: String {
        switch self {
        case .duckDuckGo: "https://duckduckgo.com/?q=%@"
        case .google: "https://www.google.com/search?q=%@"
        case .bing: "https://www.bing.com/search?q=%@"
        case .kagi: "https://kagi.com/search?q=%@"
        case .startpage: "https://www.startpage.com/do/search?q=%@"
        case .ecosia: "https://www.ecosia.org/search?q=%@"
        case .brave: "https://search.brave.com/search?q=%@"
        }
    }
}

/// A profile owns one set of website data (cookies, storage, sign-ins) and the user's
/// visual preferences. Exactly one profile is the default.
@Model
public final class Profile {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var avatar: Data?
    public var isDefault: Bool
    public var appearanceRaw: String
    public var searchEngineRaw: String
    public var createdAt: Date
    public var lastActiveAt: Date

    @Relationship(deleteRule: .cascade, inverse: \BrowserSession.profile)
    public var sessions: [BrowserSession] = []

    public var appearance: Appearance {
        get { Appearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    public var searchEngine: SearchEngine {
        get { SearchEngine(rawValue: searchEngineRaw) ?? .duckDuckGo }
        set { searchEngineRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        isDefault: Bool = false,
        appearance: Appearance = .system,
        searchEngine: SearchEngine = .duckDuckGo,
        now: Date = .now
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.appearanceRaw = appearance.rawValue
        self.searchEngineRaw = searchEngine.rawValue
        self.createdAt = now
        self.lastActiveAt = now
    }
}
