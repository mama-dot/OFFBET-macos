import Foundation
import OffbetMatcher

/// The privileged root daemon (com.offbet.helper) entry point, factored out of
/// the executable target so the logic modules (Pin, IpcServer, Resolver, …) live
/// in a library that the unit tests can `@testable import`.
///
/// Lifecycle: launched by launchd via SMAppService (KeepAlive). On start it arms
/// every protection layer, then serves IPC + heartbeats until told to stop (only
/// via a gated disable / 24h uninstall — see ARCHITECTURE.md §4).
public enum OffbetDaemon {
    public static func run() {
        Log.info("com.offbet.helper starting")

        let matcher = Matcher()   // Heartbeat + the cached blocklist refresh this
        let resolver = Resolver(matcher: matcher)
        let pf = PfController()
        let policy = BrowserPolicy()
        let dns = DnsPinning()
        let heartbeat = Heartbeat(resolver: resolver)
        let pin = Pin()
        let watchdog = Watchdog(resolver: resolver, pf: pf, policy: policy, dns: dns, heartbeat: heartbeat)

        func armAll() {
            resolver.start()          // loopback DNS resolver on 127.0.0.1:53 (local matcher)
            dns.pinToLoopback()       // point system DNS at the resolver
            pf.installAntiVpnAnchor() // M-9: block 3rd-party VPN tunnels
            policy.apply()            // M-2: disable browser DoH + block VPN extensions
            watchdog.start()          // re-arm on state drift (DNS changed, pf flushed, …)
            heartbeat.start()         // POST /api/sync every 5 min → Companion
        }

        armAll()

        let ipc = IpcServer(resolver: resolver, pf: pf, policy: policy, dns: dns, pin: pin, heartbeat: heartbeat)
        ipc.serve()   // blocks; handles status/enable/disable/pin.*/blocklist.refresh/uninstall

        RunLoop.main.run()
    }
}
