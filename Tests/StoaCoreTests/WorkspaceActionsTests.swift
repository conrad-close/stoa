import Foundation
import SwiftData
import Testing
@testable import StoaCore

@MainActor
struct WorkspaceActionsTests {
    /// Keeps the container alive for the test's scope; dropping it resets the context.
    @MainActor private final class Fixture {
        let container: ModelContainer
        let context: ModelContext
        let space: Space
        init() throws {
            container = try StoaStore.makeInMemoryContainer()
            context = container.mainContext
            let session = try StoaStore.ensureBaseline(in: context)
            space = try #require(session.spaces.first)
        }
    }

    @Test func openTabInsertsAfterActiveAndSelects() throws {
        let f = try Fixture(); let context = f.context; let space = f.space
        let a = WorkspaceActions.openTab(in: space, url: nil, title: "a", context: context)
        let b = WorkspaceActions.openTab(in: space, url: nil, title: "b", context: context)
        WorkspaceActions.selectTab(a)
        let c = WorkspaceActions.openTab(in: space, url: nil, title: "c", context: context)
        #expect(space.orderedTabs.map(\.title) == ["a", "c", "b"])
        #expect(c.isActive && !a.isActive && !b.isActive)
        #expect(space.lastActiveTabID == c.id)
    }

    @Test func closingActiveTabLandsOnPreviousTab() throws {
        let f = try Fixture(); let context = f.context; let space = f.space
        let a = WorkspaceActions.openTab(in: space, url: nil, title: "a", context: context)
        let b = WorkspaceActions.openTab(in: space, url: nil, title: "b", context: context)
        let c = WorkspaceActions.openTab(in: space, url: nil, title: "c", context: context)
        _ = a
        let landing = WorkspaceActions.closeTab(c, context: context)
        #expect(landing?.id == b.id)
        #expect(space.orderedTabs.map(\.title) == ["a", "b"])
    }

    @Test func closingFirstActiveTabLandsOnNext() throws {
        let f = try Fixture(); let context = f.context; let space = f.space
        let a = WorkspaceActions.openTab(in: space, url: nil, title: "a", context: context)
        let b = WorkspaceActions.openTab(in: space, url: nil, title: "b", context: context)
        WorkspaceActions.selectTab(a)
        let landing = WorkspaceActions.closeTab(a, context: context)
        #expect(landing?.id == b.id)
    }

    @Test func pinnedTabSnapsBackInsteadOfClosing() throws {
        let f = try Fixture(); let context = f.context; let space = f.space
        let home = URL(string: "https://mail.example")!
        let t = WorkspaceActions.openTab(in: space, url: home, title: "mail", context: context)
        WorkspaceActions.pinTab(t)
        t.url = URL(string: "https://mail.example/thread/1")
        let result = WorkspaceActions.closeTab(t, context: context)
        #expect(result?.id == t.id)
        #expect(t.url == home)
        #expect(space.tabs.count == 1)
    }

    @Test func pinnedTabsLeadTheStripAndUnpinReturnsToFront() throws {
        let f = try Fixture(); let context = f.context; let space = f.space
        let a = WorkspaceActions.openTab(in: space, url: nil, title: "a", context: context)
        let b = WorkspaceActions.openTab(in: space, url: nil, title: "b", context: context)
        WorkspaceActions.pinTab(b)
        #expect(space.orderedTabs.map(\.title) == ["b", "a"])
        WorkspaceActions.unpinTab(b)
        #expect(space.orderedTabs.map(\.title) == ["b", "a"])
        #expect(!b.isPinned && a.order == 1)
    }

    @Test func switchingSpacesRestoresLastActiveTab() throws {
        let f = try Fixture(); let context = f.context; let home = f.space
        let session = try #require(home.session)
        let work = try WorkspaceActions.addSpace(to: session, title: "Work", context: context)
        let h1 = WorkspaceActions.openTab(in: home, url: nil, title: "h1", context: context)
        let h2 = WorkspaceActions.openTab(in: home, url: nil, title: "h2", context: context)
        WorkspaceActions.selectTab(h1)
        _ = WorkspaceActions.openTab(in: work, url: nil, title: "w1", context: context)
        WorkspaceActions.selectSpace(work)
        #expect(session.activeSpaceID == work.id)
        WorkspaceActions.selectSpace(home)
        #expect(session.activeTabID == h1.id)
        #expect(h1.isActive && !h2.isActive)
    }

    @Test func freeTierSpaceLimitIsEnforced() throws {
        let f = try Fixture(); let context = f.context; let home = f.space
        let session = try #require(home.session)
        _ = try WorkspaceActions.addSpace(to: session, title: "2", limit: 3, context: context)
        _ = try WorkspaceActions.addSpace(to: session, title: "3", limit: 3, context: context)
        #expect(throws: WorkspaceActions.WorkspaceError.spaceLimitReached(3)) {
            try WorkspaceActions.addSpace(to: session, title: "4", limit: 3, context: context)
        }
    }

    @Test func deletingActiveSpaceSelectsNeighbor() throws {
        let f = try Fixture(); let context = f.context; let home = f.space
        let session = try #require(home.session)
        let work = try WorkspaceActions.addSpace(to: session, title: "Work", context: context)
        WorkspaceActions.selectSpace(work)
        WorkspaceActions.deleteSpace(work, context: context)
        try context.save()
        #expect(session.activeSpaceID == home.id)
        #expect(session.spaces.count == 1)
    }
}
