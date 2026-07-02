import Foundation

/// M-9: pf anti-VPN. Installs a dedicated pf anchor "offbet" that blocks
/// third-party VPN tunnels (utun*/ipsec*/ppp*) from relaying traffic around the
/// loopback resolver. Coexists with the user's own pf via the anchor. Knowingly
/// breaks iCloud Private Relay (acceptable for a blocker — cf. Safezino).
/// pfctl load requires root; anchor generation is pure and testable.
final class PfController {
    private let anchorPath = "/etc/pf.anchors/offbet"
    private let anchorName = "offbet"
    static let marker = "OFFBET anti-VPN v1"

    /// Anchor rule text. Blocks outbound on likely VPN tunnel interfaces.
    /// TODO: enumerate active utun*/ipsec* dynamically instead of a fixed range.
    func anchorRules() -> String {
        var lines = ["# === \(PfController.marker) ==="]
        for n in 0...7 { lines.append("block drop out on utun\(n) all") }
        lines.append("block drop out on ipsec0 all")
        lines.append("block drop out on ppp0 all")
        return lines.joined(separator: "\n") + "\n"
    }

    func installAntiVpnAnchor() {
        try? anchorRules().write(toFile: anchorPath, atomically: true, encoding: .utf8)
        _ = Shell.run("/sbin/pfctl", ["-a", anchorName, "-f", anchorPath])
        _ = Shell.run("/sbin/pfctl", ["-e"])   // enable pf if not already
        Log.info("PfController: anti-VPN anchor loaded")
    }

    func isActive() -> Bool {
        Shell.run("/sbin/pfctl", ["-a", anchorName, "-s", "rules"]).contains("block drop")
    }

    func flush() {
        _ = Shell.run("/sbin/pfctl", ["-a", anchorName, "-F", "all"])
        try? FileManager.default.removeItem(atPath: anchorPath)
    }
}
