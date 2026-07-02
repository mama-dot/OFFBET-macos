import Foundation

/// On-disk cache of the last blocklist received from /api/sync, so the resolver
/// filters from boot — before the first heartbeat, and while offline. 100% local:
/// the list lives on the device (roadmap Decision 1).
public enum BlocklistCache {
    public struct Lists: Codable { public var domains: [String]; public var tokens: [String]; public var allowlist: [String] }

    public static let defaultPath = "/Library/Application Support/OFFBET/blocklist.json"

    public static func save(domains: [String], tokens: [String], allowlist: [String], to path: String = defaultPath) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(Lists(domains: domains, tokens: tokens, allowlist: allowlist)) {
            try? d.write(to: URL(fileURLWithPath: path))
        }
    }

    public static func load(from path: String = defaultPath) -> Lists? {
        guard let d = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(Lists.self, from: d)
    }
}
