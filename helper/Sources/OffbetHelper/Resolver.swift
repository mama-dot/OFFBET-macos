import Foundation
import OffbetMatcher

// Loopback DNS resolver bound to 127.0.0.1:53 (+ [::1]:53). For each query:
//   - if the name matches the local blocklist (OffbetMatcher) → return a
//     sinkhole answer (0.0.0.0 / NXDOMAIN, or the local block page in v2);
//   - else forward to an upstream resolver over DoH (Quad9 by default).
// 100% LOCAL: only non-blocked, cache-miss lookups leave the device, and they
// carry no OFFBET identity — which gambling sites the user attempts never reaches
// an OFFBET server (roadmap Decision 1 / ARCHITECTURE.md §3).
final class Resolver {
    private let matcher = Matcher()                 // exact + suffix-walk + tokens + allowlist
    private var chronobetAllow: Set<String> = []    // sites temporarily unblocked for a session

    func start() {
        // TODO(mac): bind UDP+TCP 127.0.0.1:53 and [::1]:53 (Network framework / NIO).
        // TODO(mac): load cached blocklist from disk; refresh via Heartbeat/api sync.
        // TODO(mac): upstream DoH client (Quad9 https://dns.quad9.net/dns-query),
        //            with DNSSEC + a plain-DNS fallback only if DoH is unreachable.
        Log.info("Resolver.start() — TODO bind 127.0.0.1:53")
    }

    func reloadBlocklist(_ domains: [String], tokens: [String], allowlist: [String]) {
        // TODO(mac): matcher.replace(domains:tokens:allowlist:)
    }

    func setChronobetAllow(_ sites: [String]) { chronobetAllow = Set(sites.map { $0.lowercased() }) }
    func clearChronobetAllow() { chronobetAllow.removeAll() }

    func isBlocked(_ host: String) -> Bool {
        let h = host.lowercased()
        if chronobetAllow.contains(h) { return false }
        return matcher.isBlocked(h)
    }

    var blocklistSize: Int { matcher.count }
}
