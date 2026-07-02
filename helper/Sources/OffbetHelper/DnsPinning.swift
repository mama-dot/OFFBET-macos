import Foundation

/// Pins system DNS to the local resolver (127.0.0.1) on every active network
/// service, and re-asserts when the user changes it (the Watchdog calls
/// `isPinned()` / `pinToLoopback()`). v1 uses `networksetup` (fixed binary,
/// fixed args); SCDynamicStore is a future optimization (no shell-out).
/// The set/restore paths require root (the daemon runs as root).
final class DnsPinning {
    private let loopback = "127.0.0.1"
    private let networksetup = "/usr/sbin/networksetup"

    /// Active network services (skips '*'-prefixed disabled ones; drops the header line).
    private func services() -> [String] {
        Shell.run(networksetup, ["-listallnetworkservices"])
            .split(separator: "\n").dropFirst().map(String.init)
            .filter { !$0.hasPrefix("*") && !$0.isEmpty }
    }

    /// Point every service's DNS at the loopback resolver. Requires root.
    func pinToLoopback() {
        let svcs = services()
        for svc in svcs { _ = Shell.run(networksetup, ["-setdnsservers", svc, loopback]) }
        Log.info("DnsPinning: pinned \(svcs.count) service(s) → \(loopback)")
    }

    /// True iff every active service resolves via the loopback.
    func isPinned() -> Bool {
        let svcs = services()
        guard !svcs.isEmpty else { return false }
        for svc in svcs {
            let dns = Shell.run(networksetup, ["-getdnsservers", svc])
            if !dns.contains(loopback) { return false }   // "There aren't any DNS Servers…" or a different server
        }
        return true
    }

    /// Restore DHCP-provided DNS ("Empty"). Only on a *gated* disable/uninstall —
    /// never on a remote flag (Safezino v4 lesson). Requires root.
    func restoreUserDns() {
        for svc in services() { _ = Shell.run(networksetup, ["-setdnsservers", svc, "Empty"]) }
        Log.info("DnsPinning: restored (Empty/DHCP)")
    }
}
