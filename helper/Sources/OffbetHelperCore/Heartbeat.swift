import Foundation

/// POST /api/sync every 5 min (os=macos). Same single-endpoint contract as
/// Android/Windows: sends protection_active, blocked_attempts[], bypass_attempt;
/// receives blocklist + tokens + allowlist + premium + companion.
/// The heartbeat-gap (silence > 10 min) lets the backend alert the Companion —
/// the imparable anti-uninstall layer (ARCHITECTURE.md §4).
final class Heartbeat {
    private let apiURL = URL(string: "https://my.offbet.app/api/sync")!
    private let session = URLSession(configuration: .ephemeral)
    private var timer: Timer?
    private var blocked: [String: Int] = [:]
    private var pendingBypass: String?
    private weak var resolver: Resolver?

    /// Firebase ID token, handed over by the Electron shell after sign-in.
    var firebaseToken: String?
    private(set) var lastOk = false

    init(resolver: Resolver? = nil) { self.resolver = resolver }

    func start() {
        sync()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.sync() }
        Log.info("Heartbeat started (POST \(apiURL) every 5 min)")
    }

    func recordBlocked(domain: String) { blocked[domain, default: 0] += 1 }
    func recordBypass(kind: String) { pendingBypass = kind }

    /// Perform one sync now. `completion` gets the HTTP status (for tests).
    func sync(completion: ((Int) -> Void)? = nil) {
        var req = URLRequest(url: apiURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = firebaseToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let payload: [String: Any] = [
            "os": "macos",
            "protection_active": true,
            "blocked_attempts": blocked.map { ["domain": $0.key, "count": $0.value] },
            "bypass_attempt": pendingBypass != nil,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        session.dataTask(with: req) { [weak self] data, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            self?.lastOk = (code == 200)
            if code == 200, let data = data {
                self?.apply(data)
                self?.blocked.removeAll()
                self?.pendingBypass = nil
            }
            Log.info("Heartbeat POST /api/sync → \(code)")
            completion?(code)
        }.resume()
    }

    /// Apply the server response: refresh the local blocklist. (Premium, PIN sync,
    /// companion handled by the daemon wiring — TODO.)
    private func apply(_ data: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let domains = (obj["blocklist"] as? [String]) ?? []
        let tokens = (obj["blocklist_tokens"] as? [String]) ?? []
        let allow = (obj["allowlist"] as? [String]) ?? []
        if !domains.isEmpty || !allow.isEmpty {
            resolver?.reloadBlocklist(domains, tokens: tokens, allowlist: allow)
            BlocklistCache.save(domains: domains, tokens: tokens, allowlist: allow)
        }
    }
}
