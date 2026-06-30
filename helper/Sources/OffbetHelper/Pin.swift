import Foundation

// Offline PIN (roadmap: NEVER server-dependent — Moon's critical bug). Hash is
// stored locally (Keychain, system keychain accessible to the root daemon).
// reset_delay (12h/24h/48h/lifetime) governs recovery. The gated `disable` and
// `uninstall.request` verbs consult this.
final class Pin {
    enum ResetDelay: String { case h12, h24, h48, lifetime }

    func setConfig(hash: String, hidden: Bool, resetDelay: ResetDelay) {
        // TODO(mac): persist to Keychain (kSecClassGenericPassword), system scope.
        Log.info("Pin.setConfig() — TODO")
    }

    func verify(candidateHash: String) -> Bool {
        // TODO(mac): constant-time compare against stored hash. Count failures →
        //            Heartbeat.recordBypass("pin_fail") after N (Companion alert).
        return false
    }

    // 24h-delay uninstall flow: request → backend authorizes after the delay →
    // helper tears down (gated). Mirrors Gamban/Safezino (signed, delayed).
    func requestUninstall() -> Date {
        // TODO(mac): record request time; the actual teardown only proceeds when
        //            the backend returns disable_authorized (after the delay).
        return Date().addingTimeInterval(24 * 3600)
    }
}
