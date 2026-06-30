import Foundation

// M-9: pf anti-VPN. Installs a dedicated pf anchor "offbet" that blocks/limits
// third-party VPN tunnels (utun*/ipsec*) so a NordVPN-style tunnel can't relay
// traffic around the loopback resolver. Coexists with the user's own pf via the
// anchor. NOTE: knowingly breaks iCloud Private Relay (acceptable for a blocker,
// cf. Safezino) — document it in onboarding.
final class PfController {
    private let anchorPath = "/etc/pf.anchors/offbet"

    func installAntiVpnAnchor() {
        // TODO(mac): write anchorPath with rules blocking new states on utun*/ipsec*
        //            tunnels (except our own loopback), then:
        //              pfctl -a offbet -f /etc/pf.anchors/offbet
        //              pfctl -e            (enable pf if needed)
        //            Reference the Safezino "anti-VPN v4" structure (MAC-BENCHMARK.md).
        Log.info("PfController.installAntiVpnAnchor() — TODO")
    }

    func isActive() -> Bool {
        // TODO(mac): `pfctl -a offbet -s rules` non-empty.
        return false
    }

    func flush() {
        // Only on a *gated* disable.
        // TODO(mac): pfctl -a offbet -F all
    }
}
