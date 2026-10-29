import Foundation
import Testing
import WebKit
@testable import StoaWeb
@testable import StoaCore

struct AddressResolverTests {
    @Test func fullURLsPassThrough() {
        #expect(AddressResolver.resolve("https://example.com/a?b=1", searchEngine: .duckDuckGo) == .url(URL(string: "https://example.com/a?b=1")!))
    }

    @Test func bareHostsGetHTTPS() {
        #expect(AddressResolver.resolve("example.com", searchEngine: .duckDuckGo) == .url(URL(string: "https://example.com")!))
        #expect(AddressResolver.resolve("localhost:3000", searchEngine: .duckDuckGo) == .url(URL(string: "https://localhost:3000")!))
        #expect(AddressResolver.resolve("192.168.1.1/admin", searchEngine: .duckDuckGo) == .url(URL(string: "https://192.168.1.1/admin")!))
    }

    @Test func everythingElseSearches() {
        guard case let .search(query, url)? = AddressResolver.resolve("how do bengals purr", searchEngine: .duckDuckGo) else {
            Issue.record("expected search"); return
        }
        #expect(query == "how do bengals purr")
        #expect(url.absoluteString == "https://duckduckgo.com/?q=how%20do%20bengals%20purr")
    }

    @Test func wordsWithDotsButNoTLDStillSearch() {
        guard case .search? = AddressResolver.resolve("v1.2", searchEngine: .google) else {
            Issue.record("expected search"); return
        }
    }
}

@MainActor
struct ContentBlockerTests {
    @Test func rulesCompileIntoARuleList() async throws {
        let rule = BlockingRule(category: "ads", triggerFilter: "^https?://ads\\.example\\.com/", isBuiltIn: true)
        rule.resourceTypes = ["script", "image"]
        let store = WKContentRuleListStore(url: FileManager.default.temporaryDirectory.appending(path: "stoa-rules-\(UUID())"))!
        let list = try await ContentBlockerCompiler.compile([rule], identifier: "test", store: store)
        #expect(list.identifier == "test")
    }

    @Test func disabledRulesAreOmitted() throws {
        let on = BlockingRule(category: "ads", triggerFilter: "a")
        let off = BlockingRule(category: "ads", triggerFilter: "b")
        off.isEnabled = false
        let json = try ContentBlockerCompiler.json(for: [on, off])
        #expect(json.contains("\"a\""))
        #expect(!json.contains("\"b\""))
    }
}
