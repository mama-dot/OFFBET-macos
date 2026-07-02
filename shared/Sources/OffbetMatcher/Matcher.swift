import Foundation

/// Domain matcher — port of the Android/Windows logic. Lookup order (first hit wins):
///   1. allowlist  — exact + suffix-walk; an entry here trumps every block rule
///   2. exact      — the full normalized host is in the blocklist
///   3. suffix-walk — strip labels left-to-right (a.b.casino.com → b.casino.com → casino.com)
///   4. tokens     — case-insensitive substring patterns (admin-curated)
/// Normalization: lowercase, strip trailing dot, IDNA/punycode (TODO).
public final class Matcher {
    private var exact: Set<String> = []
    private var allow: Set<String> = []
    private var tokens: [String] = []

    public init() {}

    public func replace(domains: [String], tokens: [String], allowlist: [String]) {
        self.exact = Set(domains.map { Matcher.normalize($0) })
        self.allow = Set(allowlist.map { Matcher.normalize($0) })
        self.tokens = tokens.map { $0.lowercased() }.filter { !$0.isEmpty }
    }

    public var count: Int { exact.count }

    public func isBlocked(_ host: String) -> Bool {
        let h = Matcher.normalize(host)
        if matchesSuffix(h, in: allow) { return false }   // allowlist wins
        if exact.contains(h) { return true }
        if matchesSuffix(h, in: exact) { return true }
        for t in tokens where h.contains(t) { return true }
        return false
    }

    /// True if `host` itself, or any of its parent domains, is in `set`.
    /// (The host itself must be checked too — an exact allowlist/blocklist entry
    /// like "help.casino.com" has no parent in the set.)
    private func matchesSuffix(_ host: String, in set: Set<String>) -> Bool {
        if set.contains(host) { return true }
        var h = Substring(host)
        while let dot = h.firstIndex(of: ".") {
            h = h[h.index(after: dot)...]
            if set.contains(String(h)) { return true }
        }
        return false
    }

    static func normalize(_ s: String) -> String {
        var x = s.lowercased()
        while x.hasSuffix(".") { x.removeLast() }
        // TODO: IDNA / punycode for internationalized domains.
        return x
    }
}
