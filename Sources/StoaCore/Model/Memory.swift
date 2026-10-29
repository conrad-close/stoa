import Foundation
import SwiftData

@Model
public final class HistoryItem {
    @Attribute(.unique) public var id: UUID
    public var url: URL
    public var title: String
    public var favicon: Data?
    public var visitDate: Date
    public var visitCount: Int
    public var duration: TimeInterval
    /// Stable key for grouping visits by site (registrable domain).
    public var siteKey: String
    public var searchableContent: String?
    public var pagePreview: Data?
    public var sourceTabID: UUID?
    public var isBookmarked: Bool

    public init(id: UUID = UUID(), url: URL, title: String, siteKey: String, visitDate: Date = .now) {
        self.id = id
        self.url = url
        self.title = title
        self.visitDate = visitDate
        self.visitCount = 1
        self.duration = 0
        self.siteKey = siteKey
        self.isBookmarked = false
    }
}

@Model
public final class BookmarkFolder {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var icon: String?
    public var colorHex: String?
    public var order: Int
    public var parent: BookmarkFolder?
    public var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \BookmarkFolder.parent)
    public var children: [BookmarkFolder] = []

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.folder)
    public var bookmarks: [Bookmark] = []

    public init(id: UUID = UUID(), title: String, order: Int, parent: BookmarkFolder? = nil, now: Date = .now) {
        self.id = id
        self.title = title
        self.order = order
        self.parent = parent
        self.createdAt = now
    }
}

@Model
public final class Bookmark {
    @Attribute(.unique) public var id: UUID
    public var url: URL
    public var title: String
    public var favicon: Data?
    public var preview: Data?
    public var tags: [String]
    public var notes: String?
    public var isFavorite: Bool
    public var favoritedAt: Date?
    /// Shown as an image tile on the home page rather than a row.
    public var isVisualCard: Bool
    public var order: Int
    public var folder: BookmarkFolder?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), url: URL, title: String, order: Int, folder: BookmarkFolder? = nil, now: Date = .now) {
        self.id = id
        self.url = url
        self.title = title
        self.tags = []
        self.isFavorite = false
        self.isVisualCard = false
        self.order = order
        self.folder = folder
        self.createdAt = now
        self.updatedAt = now
    }
}

public enum DownloadStatus: String, Codable, Sendable {
    case queued, running, paused, completed, failed, cancelled
}

@Model
public final class DownloadItem {
    @Attribute(.unique) public var id: UUID
    public var filename: String
    public var originalURL: URL
    public var mimeType: String?
    public var fileSize: Int64?
    public var downloadedBytes: Int64
    public var localPath: String?
    public var resumeData: Data?
    public var statusRaw: String
    public var errorMessage: String?
    public var sourceTabID: UUID?
    public var createdAt: Date
    public var completedAt: Date?

    public var status: DownloadStatus {
        get { DownloadStatus(rawValue: statusRaw) ?? .queued }
        set { statusRaw = newValue.rawValue }
    }

    public init(id: UUID = UUID(), filename: String, originalURL: URL, now: Date = .now) {
        self.id = id
        self.filename = filename
        self.originalURL = originalURL
        self.downloadedBytes = 0
        self.statusRaw = DownloadStatus.queued.rawValue
        self.createdAt = now
    }
}

/// Free-form sticky note on the home page.
@Model
public final class StickyNote {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var content: String
    public var colorHex: String
    public var kind: String
    public var todos: Data?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), title: String = "", content: String = "", colorHex: String = "#FFE27A", now: Date = .now) {
        self.id = id
        self.title = title
        self.content = content
        self.colorHex = colorHex
        self.kind = "text"
        self.x = 0; self.y = 0; self.width = 240; self.height = 180
        self.createdAt = now
        self.updatedAt = now
    }
}
