import Foundation

/// M-2: browser managed-policies. Writes `/Library/Managed Preferences/*` plists
/// to (a) DISABLE the browsers' built-in DoH — so they use the system resolver
/// (our loopback) instead of bypassing it — and (b) block VPN/proxy extensions.
/// Without this, Chrome/Firefox/Brave built-in DoH defeats any DNS-based filter
/// (proven by GamBlock/BetBlocker in MAC-BENCHMARK.md). Honest naming only —
/// NO com.apple.* impersonation (Safezino anti-pattern).
final class BrowserPolicy {
    private let dir: String
    /// Prod dir is /Library/Managed Preferences (root); overridable for tests.
    init(managedPrefsDir: String = "/Library/Managed Preferences") { self.dir = managedPrefsDir }

    private let chromiumBundles = ["com.google.Chrome", "com.brave.Browser", "com.microsoft.Edge"]
    private var chromiumPolicy: [String: Any] {
        [
            "DnsOverHttpsMode": "off",          // use system DNS (our loopback)
            "BuiltInDnsClientEnabled": false,
            // Block all extensions; OFFBET's own extension (M-11) will be
            // force-installed + allowlisted here later.
            "ExtensionInstallBlocklist": ["*"],
        ]
    }
    private var firefoxPolicy: [String: Any] {
        ["DNSOverHTTPS": ["Enabled": false, "Locked": true]]
    }

    func apply() {
        for b in chromiumBundles { write(chromiumPolicy, "\(b).plist") }
        write(firefoxPolicy, "org.mozilla.firefox.plist")
        Log.info("BrowserPolicy applied (\(chromiumBundles.count) Chromium + Firefox) → \(dir)")
    }

    func isApplied() -> Bool {
        guard let p = read("com.google.Chrome.plist") else { return false }
        return (p["DnsOverHttpsMode"] as? String) == "off"
    }

    func remove() {
        for b in chromiumBundles { try? FileManager.default.removeItem(atPath: "\(dir)/\(b).plist") }
        try? FileManager.default.removeItem(atPath: "\(dir)/org.mozilla.firefox.plist")
    }

    // MARK: plist io
    private func write(_ dict: [String: Any], _ name: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) {
            try? data.write(to: URL(fileURLWithPath: "\(dir)/\(name)"))
        }
    }
    private func read(_ name: String) -> [String: Any]? {
        guard let d = FileManager.default.contents(atPath: "\(dir)/\(name)") else { return nil }
        return (try? PropertyListSerialization.propertyList(from: d, options: [], format: nil)) as? [String: Any]
    }
}
