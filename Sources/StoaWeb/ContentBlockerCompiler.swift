import Foundation
import WebKit
import StoaCore

/// Turns `BlockingRule`s into a compiled `WKContentRuleList` that web views attach.
@MainActor
public enum ContentBlockerCompiler {
    public static let defaultIdentifier = "stoa.blocking.main"

    /// WebKit content-blocker JSON for the enabled rules, sorted by priority.
    public static func json(for rules: [BlockingRule]) throws -> String {
        let objects = rules
            .filter(\.isEnabled)
            .sorted { $0.priority < $1.priority }
            .map(\.contentBlockerJSON)
        let data = try JSONSerialization.data(withJSONObject: objects, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    /// Compiles and caches the rule list under `identifier`.
    public static func compile(
        _ rules: [BlockingRule],
        identifier: String = defaultIdentifier,
        store: WKContentRuleListStore = .default()
    ) async throws -> WKContentRuleList {
        let encoded = try json(for: rules)
        guard let list = try await store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: encoded) else {
            throw CompileError.empty
        }
        return list
    }

    public enum CompileError: Error { case empty }
}
