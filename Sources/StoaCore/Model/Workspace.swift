import Foundation
import SwiftData

/// One session per window. Remembers where the user was.
@Model
public final class BrowserSession {
    @Attribute(.unique) public var id: UUID
    public var profile: Profile?
    public var activeSpaceID: UUID?
    public var activeTabID: UUID?
    public var windowFrame: WindowFrame?
    public var isActive: Bool
    public var createdAt: Date
    public var modifiedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Space.session)
    public var spaces: [Space] = []

    public init(id: UUID = UUID(), profile: Profile?, now: Date = .now) {
        self.id = id
        self.profile = profile
        self.isActive = true
        self.createdAt = now
        self.modifiedAt = now
    }

    /// Spaces in strip order.
    public var orderedSpaces: [Space] { spaces.sorted { $0.order < $1.order } }
}

public struct WindowFrame: Codable, Hashable, Sendable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// How a space resolves the profile it browses as.
public enum ProfileBinding: Codable, Hashable, Sendable {
    /// Use the window session's profile.
    case session
    /// Always use this profile.
    case fixed(UUID)
    /// Use whatever profile the named space resolves to.
    case chained(toSpace: UUID)
}

/// A named group of tabs with its own color, icon, and wallpaper.
@Model
public final class Space {
    @Attribute(.unique) public var id: UUID
    public var session: BrowserSession?
    public var title: String
    public var icon: String
    public var colorHex: String
    public var order: Int
    public var isDefault: Bool
    public var isActive: Bool
    public var lastActiveTabID: UUID?
    public var wallpaperData: Data?
    public var profileBinding: ProfileBinding
    public var createdAt: Date
    public var modifiedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Tab.space)
    public var tabs: [Tab] = []

    @Relationship(deleteRule: .cascade, inverse: \SplitContainer.space)
    public var splitContainers: [SplitContainer] = []

    public init(
        id: UUID = UUID(),
        title: String,
        icon: String = "square.grid.2x2",
        colorHex: String = "#7C8CF8",
        order: Int,
        isDefault: Bool = false,
        now: Date = .now
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.colorHex = colorHex
        self.order = order
        self.isDefault = isDefault
        self.isActive = false
        self.profileBinding = .session
        self.createdAt = now
        self.modifiedAt = now
    }

    /// Pinned tabs first (by order), then the strip (by order).
    public var orderedTabs: [Tab] {
        tabs.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.order < $1.order
        }
    }
}

public enum SplitDirection: String, Codable, Sendable { case horizontal, vertical }
public enum SplitLayoutMode: String, Codable, Sendable { case equal, custom }

/// Up to four tabs shown side by side inside one space.
@Model
public final class SplitContainer {
    public static let maxPanes = 4

    @Attribute(.unique) public var id: UUID
    public var space: Space?
    public var title: String?
    public var directionRaw: String
    public var layoutModeRaw: String
    public var splitRatios: [Double]
    public var focusedTabID: UUID?
    public var order: Int
    public var createdAt: Date
    public var modifiedAt: Date

    @Relationship(inverse: \Tab.splitContainer)
    public var panes: [Tab] = []

    public var direction: SplitDirection {
        get { SplitDirection(rawValue: directionRaw) ?? .horizontal }
        set { directionRaw = newValue.rawValue }
    }

    public var layoutMode: SplitLayoutMode {
        get { SplitLayoutMode(rawValue: layoutModeRaw) ?? .equal }
        set { layoutModeRaw = newValue.rawValue }
    }

    public init(id: UUID = UUID(), direction: SplitDirection = .horizontal, order: Int, now: Date = .now) {
        self.id = id
        self.directionRaw = direction.rawValue
        self.layoutModeRaw = SplitLayoutMode.equal.rawValue
        self.splitRatios = []
        self.order = order
        self.createdAt = now
        self.modifiedAt = now
    }

    public var orderedPanes: [Tab] { panes.sorted { ($0.splitPaneIndex ?? 0) < ($1.splitPaneIndex ?? 0) } }
}

@Model
public final class Tab {
    @Attribute(.unique) public var id: UUID
    public var space: Space?
    public var splitContainer: SplitContainer?
    public var url: URL?
    public var title: String
    public var favicon: Data?
    public var pinnedURL: URL?
    public var isPinned: Bool
    public var isActive: Bool
    public var isLoading: Bool
    public var isDiscarded: Bool
    public var loadingProgress: Double
    public var canGoBack: Bool
    public var canGoForward: Bool
    /// WebKit interaction state for restore after relaunch or un-discard.
    public var serializedState: Data?
    public var splitPaneIndex: Int?
    public var order: Int
    public var createdAt: Date
    public var lastActiveAt: Date

    public init(id: UUID = UUID(), url: URL?, title: String = "", order: Int, now: Date = .now) {
        self.id = id
        self.url = url
        self.title = title
        self.isPinned = false
        self.isActive = false
        self.isLoading = false
        self.isDiscarded = false
        self.loadingProgress = 0
        self.canGoBack = false
        self.canGoForward = false
        self.order = order
        self.createdAt = now
        self.lastActiveAt = now
    }
}
