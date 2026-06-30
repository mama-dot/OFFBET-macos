import Foundation

// Pins system DNS to the local resolver (127.0.0.1) on every network service,
// and re-asserts when the user changes it (the Watchdog calls verify/re-pin).
final class DnsPinning {
    func pinToLoopback() {
        // TODO(mac): for each service from `networksetup -listallnetworkservices`,
        //            `networksetup -setdnsservers <svc> 127.0.0.1` — OR preferably
        //            via SCDynamicStore (no shell-out). Store the user's previous
        //            DNS to restore on a gated disable.
        Log.info("DnsPinning.pinToLoopback() — TODO")
    }

    func isPinned() -> Bool {
        // TODO(mac): read current resolvers (scutil --dns / SCDynamicStore),
        //            true iff every active service points at 127.0.0.1.
        return false
    }

    func restoreUserDns() {
        // TODO(mac): on a *gated* disable / uninstall, set services back to "Empty"
        //            (DHCP) — never wipe based on a remote flag (Safezino v4 lesson).
        Log.info("DnsPinning.restoreUserDns() — TODO")
    }
}
