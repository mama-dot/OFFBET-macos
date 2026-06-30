import Foundation

// POST /api/sync every 5 min (os=macOS). Same single-endpoint contract as
// Android/Windows: sends protection_active, blocked_attempts[], bypass_attempt,
// pin_failed_attempts, pin_hash, custom_domains, session_request; receives
// blocklist + regulated + premium + companion + active_session.
// The heartbeat-gap (silence > 10 min) is what lets the backend alert the
// Companion — the imparable anti-uninstall layer (ARCHITECTURE.md §4).
final class Heartbeat {
    private let apiURL = URL(string: "https://my.offbet.app/api/sync")!
    private var timer: Timer?

    func start() {
        // TODO(mac): timer every 300s; build payload; POST with the Firebase token
        //            handed over by the shell; apply the response (reloadBlocklist,
        //            pin sync, premium, chronobet active_session).
        Log.info("Heartbeat.start() — TODO (POST \(apiURL) every 5 min)")
    }

    func recordBlocked(domain: String) { /* TODO: buffer for next heartbeat */ }
    func recordBypass(kind: String) { /* TODO: bypass_attempt=true on next heartbeat */ }
    var lastOk: Bool { false }
}
