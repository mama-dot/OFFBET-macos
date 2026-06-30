import Foundation

// State-based re-arm (Safezino's good idea, honestly implemented). Every ~15s,
// check the PROTECTION STATE (not just file existence): is DNS still pinned to
// loopback? is the pf anchor loaded? are browser policies present? If something
// drifted (user changed DNS, flushed pf, deleted a policy) → re-assert it and
// record a bypass_attempt for the next heartbeat. A "running but disarmed"
// daemon re-arms; it never self-wipes on a remote flag.
final class Watchdog {
    private let resolver: Resolver
    private let pf: PfController
    private let policy: BrowserPolicy
    private let dns: DnsPinning
    private var timer: Timer?

    init(resolver: Resolver, pf: PfController, policy: BrowserPolicy, dns: DnsPinning) {
        self.resolver = resolver; self.pf = pf; self.policy = policy; self.dns = dns
    }

    func start() {
        // TODO(mac): Timer every 15s:
        //   if !dns.isPinned()   { dns.pinToLoopback();   reportBypass("dns_change") }
        //   if !pf.isActive()    { pf.installAntiVpnAnchor(); reportBypass("vpn") }
        //   if !policy.isApplied(){ policy.apply() }
        Log.info("Watchdog.start() — TODO (15s state re-arm)")
    }

    private func reportBypass(_ kind: String) { /* TODO: Heartbeat.recordBypass(kind) + push incident */ }
}
