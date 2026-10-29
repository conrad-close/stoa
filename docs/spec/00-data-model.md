# 00 · Data Model

**Status:** draft v1 · **Evidence:** the shipped app's persistence schema (thirteen entity types, five model versions), read from its Core Data model on 2026-10-29. Names below are Stoa's; they describe the same state, not the same code.

Stoa persists everything in one local store (SwiftData on top of Core Data) and syncs it through CloudKit when the user turns sync on. The model has four layers: **identity** (profiles), **workspace** (sessions, spaces, split containers, tabs), **memory** (history, bookmarks, downloads, notes), and **policy** (settings, site permissions, blocking rules).

## Identity

### Profile
A profile owns a set of website data (cookies, local storage, sign-ins) and the user's visual preferences.

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| name | String | |
| avatar | Data? | user-chosen image, cropped square |
| isDefault | Bool | exactly one default profile exists |
| appearance | enum | system / light / dark |
| defaultSearchEngine | enum | |
| createdAt, lastActiveAt | Date | |

Each profile maps 1:1 to a persistent `WKWebsiteDataStore` keyed by its id. Deleting a profile removes that data store and only that data store.

## Workspace

### Session
One session per window. Remembers where the user was.

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| profileId | UUID | the profile this window browses as |
| spaces | [Space] | ordered |
| activeSpaceId, activeTabId | UUID? | restored on launch |
| windowGeometry | Rect | |
| isActive | Bool | |
| createdAt, modifiedAt | Date | |

### Space
A named group of tabs with its own color, icon, and (later) wallpaper. Free tier allows three.

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| title | String | |
| icon | String | SF Symbol name |
| colorHex | String | |
| order | Int | position in the strip |
| isDefault, isActive | Bool | |
| tabs | [Tab] | ordered; pinned tabs first |
| splitContainers | [SplitContainer] | |
| createdAt, modifiedAt | Date | |

Each space remembers its last active tab (observed in 7.1 release notes), so switching away and back restores position. A space may bind to a specific profile, share the session's profile, or chain to another space's profile (8.0 notes); that binding lives on the space as `profileBinding`.

### SplitContainer
A split view: up to four tabs shown side by side in one space.

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| title | String? | |
| direction | enum | horizontal / vertical |
| layoutMode | enum | equal / custom |
| splitRatios | [Double] | one per pane, sums to 1; the seam is draggable |
| focusedTabId | UUID? | keyboard focus inside the split |
| panels | [Tab] | ordered, max 4 |
| order | Int | |

### Tab
| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| url, title, favicon | | |
| pinnedURL | URL? | pinned tabs snap back to this on close |
| isPinned, isActive, isLoading, isDiscarded | Bool | discarded = unloaded to save memory, restored on select |
| loadingProgress | Double | |
| canGoBack, canGoForward | Bool | cached for UI |
| serializedState | Data | WebKit interaction state for restore |
| splitPanelIndex | Int? | position inside its split container, if any |
| order | Int | |
| createdAt, lastActiveAt | Date | |

A tab belongs to exactly one space and optionally one split container. Closing a tab lands on the previous tab in that space (7.1 notes).

## Memory

### HistoryItem
| Field | Notes |
|---|---|
| url, title, favicon | |
| visitDate, visitCount, duration | repeat visits increment count |
| siteHash | for grouping by site |
| searchableContent | extracted page text for Quick Search |
| pagePreview | thumbnail |
| sourceTabId | |
| isBookmarked | denormalized |

### Bookmark, BookmarkFolder
Folders nest (parent / children) and carry a color and icon. Bookmarks keep a preview, tags, notes, favorite flag, and an optional link back to the history item. `isVisualCard` marks bookmarks shown as image tiles on the home page.

### DownloadItem
filename, originalURL, mimeType, fileSize, downloadedBytes, localPath, resumeData, status (queued / running / paused / done / failed), errorMessage, sourceTab, completedAt.

### Note
Free-form sticky notes on the home page: title, content, color, type, a todos payload, and x / y / width / height.

## Policy

### Setting
A key/value table rather than a struct: key, value, dataType, category, isUserCustomized, lastModified. Lets every setting carry "has the user touched this" for reset-to-default.

### SitePermission
Per origin: camera, microphone, geolocation, notifications, popups, autoplay, cookies, localStorage. Each is allow / deny / ask. Backs the WebKit permission delegate callbacks.

### BlockingRule
Stoa's blocker compiles these into a `WKContentRuleList`. Fields mirror the content-blocker JSON: triggerFilter, resourceTypes, loadTypes, excludedDomains, restrictedDomains, actionType (block / block-cookies / css-display-none / ignore-previous), actionSelector, priority, category, isBuiltIn, isEnabled.

## Open questions (answer from Ghidra evidence)

- Collections (8.0) are not an entity. Likely a flag or grouping key on Tab, or stored in `serializedState`. Find it.
- Wallpaper per space (7.1) is not an entity field. Probably in Settings keyed by space id. Confirm.
- Passwords are not in this store (expected: Keychain). Confirm the vault's storage.
- What `OrtixBrowserSettings.category` enumerates.
