import Foundation
import StoaCore

/// Turns what the user typed into the address bar into a URL or a search.
public enum AddressResolver {
    public enum Resolution: Equatable, Sendable {
        case url(URL)
        case search(query: String, url: URL)
    }

    public static func resolve(_ input: String, searchEngine: SearchEngine) -> Resolution? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let url = URL(string: text), let scheme = url.scheme?.lowercased(),
           ["http", "https", "file", "about"].contains(scheme) {
            return .url(url)
        }
        if looksLikeHost(text), let url = URL(string: "https://\(text)") {
            return .url(url)
        }
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let urlString = searchEngine.queryTemplate.replacingOccurrences(of: "%@", with: encoded)
        guard let url = URL(string: urlString) else { return nil }
        return .search(query: text, url: url)
    }

    /// `example.com`, `localhost:3000`, `192.168.1.1/admin`: a host with no spaces and a dot or port.
    static func looksLikeHost(_ text: String) -> Bool {
        guard !text.contains(" ") else { return false }
        let hostPart = text.split(separator: "/", maxSplits: 1).first.map(String.init) ?? text
        if hostPart.lowercased().hasPrefix("localhost") { return true }
        let host = hostPart.split(separator: ":").first.map(String.init) ?? hostPart
        guard host.contains(".") else { return false }
        let labels = host.split(separator: ".")
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }) else { return false }
        if labels.allSatisfy({ Int($0) != nil }) { return labels.count == 4 }
        let tld = labels.last!
        return tld.count >= 2 && tld.allSatisfy(\.isLetter)
    }
}
