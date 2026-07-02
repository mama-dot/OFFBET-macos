import Foundation

/// Offline PIN (roadmap: NEVER server-dependent — Moon's critical bug). The hash
/// is stored locally and verified offline; `/api/sync` only *syncs* the hash
/// across devices. `resetDelay` (12h/24h/48h/lifetime) governs the 24h-style
/// uninstall/recovery flow.
final class Pin {
    enum ResetDelay: String, Codable { case h12, h24, h48, lifetime }

    private struct Config: Codable {
        var hash: String
        var hidden: Bool
        var resetDelay: ResetDelay
        var uninstallRequestedAt: Date?
    }

    private let path: String
    /// Prod path is root-owned under Application Support; overridable for tests.
    init(path: String = "/Library/Application Support/OFFBET/pin.json") { self.path = path }

    // MARK: storage
    private func load() -> Config? {
        guard let d = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(Config.self, from: d)
    }
    private func save(_ c: Config) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(c) { try? d.write(to: URL(fileURLWithPath: path)) }
    }

    // MARK: API
    func setConfig(hash: String, hidden: Bool, resetDelay: ResetDelay) {
        var c = load() ?? Config(hash: hash, hidden: hidden, resetDelay: resetDelay, uninstallRequestedAt: nil)
        c.hash = hash; c.hidden = hidden; c.resetDelay = resetDelay
        save(c)
        Log.info("Pin config stored (hidden=\(hidden), delay=\(resetDelay.rawValue))")
    }

    /// Constant-time comparison of the candidate hash to the stored hash.
    func verify(candidateHash: String) -> Bool {
        guard let stored = load()?.hash, !stored.isEmpty else { return false }
        return Pin.constantTimeEquals(stored, candidateHash)
    }

    static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        if x.count != y.count { return false }
        var diff: UInt8 = 0
        for i in 0..<x.count { diff |= x[i] ^ y[i] }
        return diff == 0
    }

    // MARK: 24h-delay uninstall
    @discardableResult
    func requestUninstall() -> Date {
        var c = load() ?? Config(hash: "", hidden: false, resetDelay: .h24, uninstallRequestedAt: nil)
        let now = Date()
        c.uninstallRequestedAt = now
        save(c)
        let eligible = now.addingTimeInterval(Pin.delaySeconds(c.resetDelay))
        Log.info("Uninstall requested; eligible at \(eligible)")
        return eligible
    }

    func uninstallEligible() -> Bool {
        guard let c = load(), let req = c.uninstallRequestedAt else { return false }
        return Date() >= req.addingTimeInterval(Pin.delaySeconds(c.resetDelay))
    }

    static func delaySeconds(_ d: ResetDelay) -> TimeInterval {
        switch d {
        case .h12: return 12 * 3600
        case .h24: return 24 * 3600
        case .h48: return 48 * 3600
        case .lifetime: return .greatestFiniteMagnitude
        }
    }
}
