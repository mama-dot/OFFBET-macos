import Foundation

/// State-based re-arm (Safezino's good idea, honestly implemented). Every ~15s,
/// check the PROTECTION STATE (not just file existence): is DNS still pinned to
/// loopback? is the pf anchor loaded? are browser policies present? If something
/// drifted (user changed DNS, flushed pf, deleted a policy) → re-assert it and
/// record a bypass_attempt for the next heartbeat. A "running but disarmed"
/// daemon re-arms; it NEVER self-wipes on a remote flag.
final class Watchdog {
    private let resolver: Resolver
    private let pf: PfController
    private let policy: BrowserPolicy
    private let dns: DnsPinning
    private weak var heartbeat: Heartbeat?
    private var timer: Timer?

    init(resolver: Resolver, pf: PfController, policy: BrowserPolicy, dns: DnsPinning, heartbeat: Heartbeat? = nil) {
        self.resolver = resolver; self.pf = pf; self.policy = policy; self.dns = dns; self.heartbeat = heartbeat
    }

    func start(interval: TimeInterval = 15) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        Log.info("Watchdog started (state re-arm every \(Int(interval))s)")
    }

    func stop() { timer?.invalidate(); timer = nil }

    /// One re-arm pass. Exposed for testing.
    func tick() {
        if !dns.isPinned() { Log.warn("Watchdog: DNS drifted → re-pin"); dns.pinToLoopback(); heartbeat?.recordBypass(kind: "dns_change") }
        if !pf.isActive() { Log.warn("Watchdog: pf anchor gone → reload"); pf.installAntiVpnAnchor(); heartbeat?.recordBypass(kind: "vpn") }
        if !policy.isApplied() { Log.warn("Watchdog: browser policy gone → reapply"); policy.apply() }
    }
}
