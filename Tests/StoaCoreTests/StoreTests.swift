import Foundation
import SwiftData
import Testing
@testable import StoaCore

@MainActor
struct StoreTests {
    @Test func baselineCreatesDefaultProfileSessionAndSpace() throws {
        let container = try StoaStore.makeInMemoryContainer()
        let context = container.mainContext
        let session = try StoaStore.ensureBaseline(in: context)
        #expect(session.profile?.isDefault == true)
        #expect(session.spaces.count == 1)
        #expect(session.spaces.first?.isDefault == true)
        #expect(session.activeSpaceID == session.spaces.first?.id)

        // Idempotent.
        let again = try StoaStore.ensureBaseline(in: context)
        #expect(again.id == session.id)
        #expect(try context.fetch(FetchDescriptor<Profile>()).count == 1)
    }

    @Test func pinnedTabsSortFirst() throws {
        let container = try StoaStore.makeInMemoryContainer()
        let context = container.mainContext
        let session = try StoaStore.ensureBaseline(in: context)
        let space = try #require(session.spaces.first)
        let a = Tab(url: URL(string: "https://a.example"), title: "a", order: 0)
        let b = Tab(url: URL(string: "https://b.example"), title: "b", order: 1)
        let c = Tab(url: URL(string: "https://c.example"), title: "c", order: 2)
        c.isPinned = true
        for t in [a, b, c] { t.space = space; context.insert(t) }
        try context.save()
        #expect(space.orderedTabs.map(\.title) == ["c", "a", "b"])
    }

    @Test func deletingProfileCascadesToSessionsAndSpaces() throws {
        let container = try StoaStore.makeInMemoryContainer()
        let context = container.mainContext
        let session = try StoaStore.ensureBaseline(in: context)
        let profile = try #require(session.profile)
        context.delete(profile)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<BrowserSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Space>()).isEmpty)
    }

    @Test func blockingRuleEmitsContentBlockerJSON() {
        let rule = BlockingRule(category: "ads", triggerFilter: "^https?://ads\\.example\\.com/", isBuiltIn: true)
        rule.resourceTypes = ["script", "image"]
        rule.unlessDomain = ["example.com"]
        let json = rule.contentBlockerJSON
        let trigger = json["trigger"] as? [String: Any]
        let action = json["action"] as? [String: Any]
        #expect(trigger?["url-filter"] as? String == "^https?://ads\\.example\\.com/")
        #expect((trigger?["resource-type"] as? [String]) == ["script", "image"])
        #expect((trigger?["unless-domain"] as? [String]) == ["example.com"])
        #expect(action?["type"] as? String == "block")
    }
}
