import Foundation
import SwiftData

/// Tab and space operations with the rules the UI relies on. Pure model mutations;
/// the caller saves the context.
@MainActor
public enum WorkspaceActions {
    // MARK: Tabs

    /// Opens a tab in `space`, placed right after the active tab (or at the end), and selects it.
    @discardableResult
    public static func openTab(in space: Space, url: URL?, title: String = "", select: Bool = true, context: ModelContext, now: Date = .now) -> BrowserTab {
        let strip = space.orderedTabs.filter { !$0.isPinned }
        let insertAt: Int
        if let active = strip.firstIndex(where: { $0.id == space.lastActiveTabID }) {
            insertAt = active + 1
        } else {
            insertAt = strip.count
        }
        for (i, t) in strip.enumerated() where i >= insertAt { t.order = i + 1 }
        let tab = BrowserTab(url: url, title: title, order: insertAt, now: now)
        tab.space = space
        context.insert(tab)
        if select { selectTab(tab, now: now) }
        space.modifiedAt = now
        return tab
    }

    /// Makes `tab` the active tab of its space and records it as the space's last active tab.
    public static func selectTab(_ tab: BrowserTab, now: Date = .now) {
        guard let space = tab.space else { return }
        for t in space.tabs { t.isActive = (t.id == tab.id) }
        tab.lastActiveAt = now
        tab.isDiscarded = false
        space.lastActiveTabID = tab.id
        space.session?.activeTabID = tab.id
    }

    /// Closes `tab`. A pinned tab is not closed; it snaps back to its pinned URL.
    /// Focus lands on the previous tab in strip order, or the next one if it was first.
    /// Returns the newly selected tab, if any.
    @discardableResult
    public static func closeTab(_ tab: BrowserTab, context: ModelContext, now: Date = .now) -> BrowserTab? {
        guard let space = tab.space else { context.delete(tab); return nil }
        if tab.isPinned {
            tab.url = tab.pinnedURL ?? tab.url
            return tab
        }
        let ordered = space.orderedTabs
        let index = ordered.firstIndex { $0.id == tab.id } ?? 0
        let wasActive = tab.isActive || space.lastActiveTabID == tab.id
        let remaining = ordered.filter { $0.id != tab.id }
        for (i, t) in remaining.filter({ !$0.isPinned }).enumerated() { t.order = i }
        tab.space = nil // detach now so the strip updates before the context saves
        tab.splitContainer = nil
        context.delete(tab)
        space.modifiedAt = now
        guard wasActive, !remaining.isEmpty else { return nil }
        let landing = remaining[max(0, min(index - 1, remaining.count - 1))]
        selectTab(landing, now: now)
        return landing
    }

    /// Pins a tab: it moves to the pinned section and remembers its URL to snap back to.
    public static func pinTab(_ tab: BrowserTab, now: Date = .now) {
        guard let space = tab.space, !tab.isPinned else { return }
        tab.isPinned = true
        tab.pinnedURL = tab.url
        tab.order = (space.tabs.filter(\.isPinned).map(\.order).max() ?? -1) + 1
        renumberStrip(in: space)
        space.modifiedAt = now
    }

    public static func unpinTab(_ tab: BrowserTab, now: Date = .now) {
        guard let space = tab.space, tab.isPinned else { return }
        tab.isPinned = false
        tab.pinnedURL = nil
        tab.order = -1 // front of the strip
        renumberStrip(in: space)
        space.modifiedAt = now
    }

    /// Moves `tab` to `index` within its section (pinned or strip).
    public static func moveTab(_ tab: BrowserTab, to index: Int, now: Date = .now) {
        guard let space = tab.space else { return }
        var section = space.orderedTabs.filter { $0.isPinned == tab.isPinned && $0.id != tab.id }
        section.insert(tab, at: max(0, min(index, section.count)))
        for (i, t) in section.enumerated() { t.order = i }
        space.modifiedAt = now
    }

    /// Moves `tab` to another space, appended to that space's strip.
    public static func moveTab(_ tab: BrowserTab, to destination: Space, now: Date = .now) {
        guard let source = tab.space, source.id != destination.id else { return }
        tab.splitContainer = nil
        tab.splitPaneIndex = nil
        tab.space = destination
        tab.order = (destination.tabs.filter { !$0.isPinned }.map(\.order).max() ?? -1) + 1
        renumberStrip(in: source)
        source.modifiedAt = now
        destination.modifiedAt = now
    }

    private static func renumberStrip(in space: Space) {
        for (i, t) in space.orderedTabs.filter({ !$0.isPinned }).enumerated() { t.order = i }
        for (i, t) in space.orderedTabs.filter(\.isPinned).enumerated() { t.order = i }
    }

    // MARK: Spaces

    /// Switching to a space restores the tab it was last on.
    public static func selectSpace(_ space: Space, now: Date = .now) {
        guard let session = space.session else { return }
        for s in session.spaces { s.isActive = (s.id == space.id) }
        session.activeSpaceID = space.id
        if let id = space.lastActiveTabID, let tab = space.tabs.first(where: { $0.id == id }) {
            selectTab(tab, now: now)
        } else if let first = space.orderedTabs.first {
            selectTab(first, now: now)
        } else {
            session.activeTabID = nil
        }
        session.modifiedAt = now
    }

    /// Creates a space at the end of the strip. `limit` enforces the free-tier cap when non-nil.
    @discardableResult
    public static func addSpace(to session: BrowserSession, title: String, limit: Int? = nil, context: ModelContext, now: Date = .now) throws -> Space {
        if let limit, session.spaces.count >= limit { throw WorkspaceError.spaceLimitReached(limit) }
        let space = Space(title: title, order: (session.spaces.map(\.order).max() ?? -1) + 1, now: now)
        space.session = session
        context.insert(space)
        return space
    }

    /// Deletes a space. If it was active, the neighbor to the left (or right) becomes active.
    public static func deleteSpace(_ space: Space, context: ModelContext, now: Date = .now) {
        guard let session = space.session else { context.delete(space); return }
        let ordered = session.orderedSpaces
        let index = ordered.firstIndex { $0.id == space.id } ?? 0
        let wasActive = session.activeSpaceID == space.id
        let remaining = ordered.filter { $0.id != space.id }
        for (i, s) in remaining.enumerated() { s.order = i }
        space.session = nil
        context.delete(space)
        if wasActive, !remaining.isEmpty {
            selectSpace(remaining[max(0, min(index - 1, remaining.count - 1))], now: now)
        }
    }

    public enum WorkspaceError: Error, Equatable {
        case spaceLimitReached(Int)
    }
}
