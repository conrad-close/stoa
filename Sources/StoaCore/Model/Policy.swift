import Foundation
import SwiftData

/// Key/value settings table so every setting can say whether the user touched it.
@Model
public final class Setting {
    @Attribute(.unique) public var key: String
    public var value: String
    public var dataType: String
    public var category: String
    public var isUserCustomized: Bool
    public var lastModified: Date

    public init(key: String, value: String, dataType: String, category: String, now: Date = .now) {
        self.key = key
        self.value = value
        self.dataType = dataType
        self.category = category
        self.isUserCustomized = false
        self.lastModified = now
    }
}

public enum PermissionDecision: String, Codable, Sendable { case ask, allow, deny }

/// Per-origin decisions that back WebKit's permission delegate callbacks.
@Model
public final class SitePermission {
    @Attribute(.unique) public var origin: String
    public var cameraRaw: String
    public var microphoneRaw: String
    public var geolocationRaw: String
    public var notificationsRaw: String
    public var popupsRaw: String
    public var autoplayRaw: String
    public var cookiesRaw: String
    public var localStorageRaw: String
    public var lastUpdated: Date

    public init(origin: String, now: Date = .now) {
        self.origin = origin
        let ask = PermissionDecision.ask.rawValue
        self.cameraRaw = ask; self.microphoneRaw = ask; self.geolocationRaw = ask
        self.notificationsRaw = ask; self.popupsRaw = ask; self.autoplayRaw = ask
        self.cookiesRaw = PermissionDecision.allow.rawValue
        self.localStorageRaw = PermissionDecision.allow.rawValue
        self.lastUpdated = now
    }

    public var camera: PermissionDecision { get { .init(rawValue: cameraRaw) ?? .ask } set { cameraRaw = newValue.rawValue } }
    public var microphone: PermissionDecision { get { .init(rawValue: microphoneRaw) ?? .ask } set { microphoneRaw = newValue.rawValue } }
    public var geolocation: PermissionDecision { get { .init(rawValue: geolocationRaw) ?? .ask } set { geolocationRaw = newValue.rawValue } }
    public var notifications: PermissionDecision { get { .init(rawValue: notificationsRaw) ?? .ask } set { notificationsRaw = newValue.rawValue } }
    public var popups: PermissionDecision { get { .init(rawValue: popupsRaw) ?? .ask } set { popupsRaw = newValue.rawValue } }
    public var autoplay: PermissionDecision { get { .init(rawValue: autoplayRaw) ?? .ask } set { autoplayRaw = newValue.rawValue } }
}

public enum BlockingActionType: String, Codable, Sendable {
    case block = "block"
    case blockCookies = "block-cookies"
    case cssDisplayNone = "css-display-none"
    case ignorePreviousRules = "ignore-previous-rules"
}

/// One content-blocker rule. Compiled into a `WKContentRuleList` by StoaWeb.
@Model
public final class BlockingRule {
    @Attribute(.unique) public var id: UUID
    public var category: String
    public var triggerFilter: String
    public var resourceTypes: [String]
    public var loadTypes: [String]
    public var ifDomain: [String]
    public var unlessDomain: [String]
    public var actionTypeRaw: String
    public var actionSelector: String?
    public var priority: Int
    public var isBuiltIn: Bool
    public var isEnabled: Bool
    public var createdAt: Date

    public var actionType: BlockingActionType {
        get { BlockingActionType(rawValue: actionTypeRaw) ?? .block }
        set { actionTypeRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        category: String,
        triggerFilter: String,
        actionType: BlockingActionType = .block,
        isBuiltIn: Bool = false,
        now: Date = .now
    ) {
        self.id = id
        self.category = category
        self.triggerFilter = triggerFilter
        self.resourceTypes = []
        self.loadTypes = []
        self.ifDomain = []
        self.unlessDomain = []
        self.actionTypeRaw = actionType.rawValue
        self.priority = 0
        self.isBuiltIn = isBuiltIn
        self.isEnabled = true
        self.createdAt = now
    }

    /// The WebKit content-blocker JSON object for this rule.
    public var contentBlockerJSON: [String: Any] {
        var trigger: [String: Any] = ["url-filter": triggerFilter]
        if !resourceTypes.isEmpty { trigger["resource-type"] = resourceTypes }
        if !loadTypes.isEmpty { trigger["load-type"] = loadTypes }
        if !ifDomain.isEmpty { trigger["if-domain"] = ifDomain }
        if !unlessDomain.isEmpty { trigger["unless-domain"] = unlessDomain }
        var action: [String: Any] = ["type": actionType.rawValue]
        if let actionSelector, actionType == .cssDisplayNone { action["selector"] = actionSelector }
        return ["trigger": trigger, "action": action]
    }
}
