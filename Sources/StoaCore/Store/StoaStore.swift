import Foundation
import SwiftData

/// Builds the app's model container and enforces first-launch invariants.
public enum StoaStore {
    public static let schema = Schema([
        Profile.self, BrowserSession.self, Space.self, SplitContainer.self, Tab.self,
        HistoryItem.self, BookmarkFolder.self, Bookmark.self, DownloadItem.self, StickyNote.self,
        Setting.self, SitePermission.self, BlockingRule.self,
    ])

    /// On-disk container under Application Support/Stoa.
    public static func makeContainer(directory: URL? = nil) throws -> ModelContainer {
        let dir = try directory ?? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "Stoa", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let config = ModelConfiguration("Stoa", schema: schema, url: dir.appending(path: "Stoa.store"))
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// In-memory container for tests and previews.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration("Stoa", schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Guarantees one default profile, one active session, and one default space exist.
    @MainActor
    public static func ensureBaseline(in context: ModelContext, now: Date = .now) throws -> BrowserSession {
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let profile: Profile
        if let existing = profiles.first(where: { $0.isDefault }) ?? profiles.first {
            profile = existing
            profile.isDefault = true
        } else {
            profile = Profile(name: "Personal", isDefault: true, now: now)
            context.insert(profile)
        }

        let sessions = try context.fetch(FetchDescriptor<BrowserSession>())
        let session: BrowserSession
        if let existing = sessions.first(where: { $0.isActive }) ?? sessions.first {
            session = existing
        } else {
            session = BrowserSession(profile: profile, now: now)
            context.insert(session)
        }

        if session.spaces.isEmpty {
            let space = Space(title: "Home", order: 0, isDefault: true, now: now)
            space.isActive = true
            space.session = session
            context.insert(space)
            session.activeSpaceID = space.id
        }
        try context.save()
        return session
    }
}
