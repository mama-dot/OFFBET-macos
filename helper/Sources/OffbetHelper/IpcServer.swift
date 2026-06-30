import Foundation

// Local IPC server for the Electron shell. Newline-delimited JSON over a
// root-owned unix socket at /var/run/offbet-helper.sock (0600). Fixed verb set
// only — never executes arbitrary commands (BetBlocker anti-pattern). See
// docs/IPC-CONTRACT.md.
final class IpcServer {
    private let resolver: Resolver
    private let pf: PfController
    private let policy: BrowserPolicy
    private let dns: DnsPinning
    private let pin: Pin
    private let heartbeat: Heartbeat

    init(resolver: Resolver, pf: PfController, policy: BrowserPolicy, dns: DnsPinning, pin: Pin, heartbeat: Heartbeat) {
        self.resolver = resolver; self.pf = pf; self.policy = policy
        self.dns = dns; self.pin = pin; self.heartbeat = heartbeat
    }

    func serve() {
        // TODO(mac): create the unix socket (0600, root), accept connections,
        //            authenticate the caller (per-install secret + verify the
        //            connecting binary's code signature where possible), then
        //            dispatch the JSON `cmd` to handle(_:).
        Log.info("IpcServer.serve() — TODO bind /var/run/offbet-helper.sock")
    }

    // Maps a command to an action. Destructive verbs (disable/uninstall) are GATED.
    private func handle(_ cmd: String, _ args: [String: Any]) -> [String: Any] {
        switch cmd {
        case "status":
            return [
                "active": dns.isPinned() && pf.isActive(),
                "dnsPinned": dns.isPinned(),
                "pfActive": pf.isActive(),
                "browserPolicy": policy.isApplied(),
                "blocklistSize": resolver.blocklistSize,
                "lastHeartbeatOk": heartbeat.lastOk,
            ]
        case "enable":
            dns.pinToLoopback(); pf.installAntiVpnAnchor(); policy.apply()
            return ["ok": true]
        case "disable":
            // GATED: require a valid PIN token (offline-verified) or 24h authorization.
            guard let token = args["pinToken"] as? String, pin.verify(candidateHash: token) else {
                return ["error": "pin_required"]
            }
            dns.restoreUserDns(); pf.flush(); policy.remove()
            return ["ok": true]
        case "chronobet.start":
            let sites = (args["sites"] as? [String]) ?? []
            resolver.setChronobetAllow(sites)
            return ["ok": true]
        case "chronobet.stop":
            resolver.clearChronobetAllow()
            return ["ok": true]
        case "uninstall.request":
            let eligible = pin.requestUninstall()
            return ["ok": true, "eligibleAt": eligible.timeIntervalSince1970]
        default:
            return ["error": "unknown_cmd"]
        }
    }
}
