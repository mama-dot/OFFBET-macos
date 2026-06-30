import Foundation

// M-2: browser managed-policies. Writes /Library/Managed Preferences/* (and the
// per-browser policy dirs) to (a) DISABLE the browser's built-in DoH — so the
// browser uses the system resolver (our loopback) instead of bypassing it — and
// (b) block VPN/proxy extensions. Without this, Chrome/Firefox/Brave built-in
// DoH defeats any DNS-based filter (proven by GamBlock/BetBlocker).
final class BrowserPolicy {
    func apply() {
        // Chrome/Brave/Edge (Chromium): managed prefs
        //   DnsOverHttpsMode = "off"
        //   BuiltInDnsClientEnabled = false
        //   ExtensionInstallBlocklist = ["*"]  (+ allowlist OFFBET's own ext for M-11)
        // Firefox policies.json:
        //   DNSOverHTTPS = { "Enabled": false, "Locked": true }
        //   Extensions / InstallAddonsPermission as needed
        //
        // TODO(mac): write:
        //   /Library/Managed Preferences/com.google.Chrome.plist
        //   /Library/Managed Preferences/com.brave.Browser.plist
        //   /Library/Managed Preferences/com.microsoft.Edge.plist
        //   /Library/Managed Preferences/org.mozilla.firefox.plist
        //   /Applications/Firefox.app/Contents/Resources/distribution/policies.json
        // Honest naming only — NO com.apple.* impersonation (Safezino anti-pattern).
        Log.info("BrowserPolicy.apply() — TODO")
    }

    func isApplied() -> Bool {
        // TODO(mac): read back DnsOverHttpsMode == "off" on installed browsers.
        return false
    }

    func remove() {
        // Only on a gated disable / uninstall.
    }
}
