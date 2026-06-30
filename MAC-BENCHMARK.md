# OFFBET macOS — Competitor Benchmark & Anti-Bypass Notes

Living document. For every gambling-blocker / content-filter / parental-control
app that ships on **macOS**, we record how it filters, how it resists bypass &
uninstall, how it's distributed/signed, and which macOS-specific surfaces it
covers. From the **OFFBET vs competitor** gap we derive a prioritized backlog
(M-IDs) for the macOS app.

> Sibling of the Android doc (`OFFBET-android/COMPETITOR-ANALYSIS.md`, items
> C-1…C-11). Same philosophy, macOS specifics.

---

## 0. Context — what OFFBET macOS should be

Per the roadmap (v8.2) the desktop philosophy is **"maximum webapp"**: a thin
shell renders the existing web UI (`my.offbet.app` — account, settings,
Companion, PIN config) and a **native privileged component** does the
system-level work a webview can't. The macOS app **mirrors the Windows UX/UI**
(same Electron shell) — the only platform-specific part is the filtering engine.

**Important correction to the v8.2 PDF.** The PDF planned macOS = Electron +
Swift **Launch Daemon writing `/etc/hosts`**. The Windows implementation has
since moved **past** that: it dropped the hosts file ("exact domains only,
crippling at 290k entries") for a **loopback DNS resolver** carrying the full
Android matcher. And the leading mac competitor (Gamban, audited below) uses a
**NetworkExtension system extension**, not `/etc/hosts`. So:

> **macOS filtering target = NetworkExtension (DNS-proxy + content-filter system
> extension), not `/etc/hosts`.** Electron shell mirrors Windows; the filter is
> a native Swift system extension. `/etc/hosts` is a last-resort fallback only.

Reuse map (consistent with Android/Windows):
- ✅ Web UI (`my.offbet.app`) in the shell — zero new screens
- ✅ Backend `/api/sync`, blocklist, Companion, PIN, Firebase auth — as-is (`os=macOS`)
- ✅ Matcher logic — port (Android Kotlin / Windows C# → Swift, or shared Swift Package with iOS)
- 🆕 NetworkExtension filtering layer (DNS-proxy / content-filter)
- 🆕 Browser managed-policy injection (DoH + extension lockdown) — see M-2
- 🆕 macOS bypass detection (DNS/VPN/profile/extension state)

---

## 1. Methodology — dissecting a macOS competitor

Most of this needs a **Mac** (codesign/pluginkit/systemextensionsctl). On Linux
you can still read an ISO-9660 `.dmg` and `strings` the binaries + decode the
embedded `embedded.provisionprofile` (base64 → it lists entitlements in clear).

On the MacBook, per competitor:
1. `hdiutil attach X.dmg` → inspect `*.app` (or expand the `.pkg`: `pkgutil --expand-full`).
2. **Signing & distribution**: `codesign -dvvv --entitlements - --xml X.app`
   → team id, bundle id, designated requirement, App Store vs Developer ID.
3. **System extension**: `Contents/Library/SystemExtensions/*.systemextension/Contents/Info.plist`
   → `NEProviderClasses` (which of `com.apple.networkextension.dns-proxy` /
   `.filter-data` / `.packet-tunnel` / `.app-proxy`). Live: `systemextensionsctl list`.
4. **Privileged helper / daemon** (anti-uninstall): `Contents/Library/LaunchServices/*`
   (`SMJobBless`/`SMAppService`), `/Library/LaunchDaemons`, `/Library/LaunchAgents`.
5. **Browser policy injection** (anti-bypass): `/Library/Managed Preferences/*`,
   `/Library/Preferences/com.google.Chrome.plist` (`DnsOverHttpsMode`,
   `ExtensionInstallBlocklist`), `/etc/opt/chrome/policies/managed/*`,
   Firefox `…/distribution/policies.json` (`DNSOverHTTPS`, `Extensions.Blocked`).
6. **Configuration profile**: `profiles list` / System Settings → Profiles
   (`.mobileconfig` payloads: `com.apple.dnsProxy.managed`, `com.apple.dnsSettings.managed`).
7. **DNS state it sets**: `scutil --dns`, `networksetup -getdnsservers Wi-Fi`.
8. **Anti-tamper**: signature checks on its own files, SIP reliance, what
   happens on `kill`/uninstall, recovery-mode behaviour.

---

## 2. macOS-specific bypass vectors (the checklist)

A desktop with an admin account is more permissive than a phone. Track which
each competitor closes:

| Vector | Notes |
|--------|-------|
| Change system DNS (`networksetup` / Network panel) | hosts/loopback approaches; NE DNS-proxy survives it |
| Third-party **VPN** (Network Extension or tun) | only one config active; a tunnel can shadow filtering |
| Browser **DoH / DNS-over-HTTPS** (Chrome/Firefox/Brave/Edge built-in) | the #1 desktop bypass — needs **browser managed policy** to disable/pin |
| Browser **VPN/proxy extensions** | needs `ExtensionInstallBlocklist` managed policy |
| Tor / Brave onion / Vivaldi own DNS | app-level lockout or content-filter |
| Disable the system extension (System Settings → Login Items & Extensions) | macOS lets the user toggle 3rd-party extensions |
| Remove a configuration profile (if not supervised) | only **supervised/MDM** profiles are non-removable |
| Delete `/etc/hosts` entries / kill the daemon | watchdog must re-assert |
| Quit the app / unload the LaunchDaemon | `SMAppService` keep-alive |
| New **admin user** / standard-vs-admin account | true lockdown ≈ run user as standard |
| **Recovery mode / disable SIP / boot another volume** | unblockable from userland (same class as Android safe-mode) |
| Time Machine restore to pre-install | unblockable; detect via heartbeat |
| Uninstall (drag to Trash / pkg uninstaller) | Apple forbids true prevention → **heartbeat-gap is the real lever** |

---

## 3. OFFBET macOS backlog (seeded from audits)

| ID | Item | Source | Priority | Status |
|----|------|--------|----------|--------|
| M-1 | **NetworkExtension filtering** — DNS-proxy + content-filter *system extension* (Developer ID), carrying the OFFBET matcher. Replaces the v8.2 `/etc/hosts` plan. | Gamban | 🔴 HIGH | ⬜ TODO |
| M-2 | **Browser managed-policy injection** — write Chrome/Edge/Brave/Firefox managed policies to (a) **disable built-in DoH** or pin it (`DnsOverHttpsMode=off`), (b) **block VPN/proxy extensions** (`ExtensionInstallBlocklist`). Closes the #1 desktop bypass. | Gamban (`ExtensionInstallBlocklist`, `TrrModeTrustedResolverOnly`, `browserPolicy`) | 🔴 HIGH | ⬜ TODO |
| M-3 | **NEDNSSettings / DNS-proxy config** to own system DNS resolution (the `dns-settings` entitlement). | Gamban | 🟡 MED | ⬜ TODO |
| M-4 | **Developer ID direct distribution + notarization** (mirrors Windows direct-download). App Store later if useful. | Gamban (DIRECT profile) | 🔴 HIGH | ⬜ TODO |
| M-5 | **Signature-verified uninstaller + anti-tamper** on the app's own files; `SMAppService` keep-alive so quitting/unloading re-launches. (Apple concedes true anti-uninstall is impossible — see M-6.) | Gamban (`UninstallerEntryPoint`+`signatureVerification`) | 🟡 MED | ⬜ TODO |
| M-6 | **Companion heartbeat-gap → alert** — the real anti-uninstall lever on macOS (Apple forbids prevention; Gamban's own EULA concedes uninstall). Reuse the existing backend cron. | OFFBET-original (cross-platform) | 🔴 HIGH | ✅ exists backend-side |
| M-7 | **Standard (non-admin) account guidance** for true lockdown (Screen Time model) — onboarding nudge. | macOS constraint | 🟢 LOW | ⬜ TODO |
| M-8 | **Bypass-state detection** — watch DNS change, active 3rd-party VPN, extension disabled, profile removed → heartbeat `bypass_attempt`. | parallels Android C-6/C-11 | 🟡 MED | ⬜ TODO |

---

## 4. Competitors to audit

Gambling-specific: **Gamban** ✅ (below), **Gamban-alt / BetBlocker** (desktop?),
**Safezino** (mac?). Broader focus/content filters (same mechanisms):
**Freedom.to**, **Cold Turkey Blocker**, **SelfControl** (open-source),
**Focus (heyfocus)**, **1Blocker**, **AdGuard for Mac**, **Qustodio (Mac)**,
**Net Nanny / Mobicip / Bark**. Reference (don't ship, but study): **Apple
Screen Time** content filter + passcode model.

---

## 5. Audits

### Gamban — `com.gamban.Gamban` v4.0 (desktop) · audited 2026-06-30 (from `Gamban_Setup.dmg`, Linux-side)

> Closest competitor in purpose on macOS: a paid, gambling-specific blocker.
> The DMG is ISO-9660; analysis from `strings` + the decoded
> `embedded.provisionprofile`. **Deep dive (codesign/systemextensionsctl/browser
> policies on disk) still TODO on the MacBook.**

- **Stack:** Swift app `com.gamban.Gamban` + framework `GambanKit` (clean modular
  arch: Networking, FileSystem, DaemonManager, BackendClient, **BrowserPolicy**,
  TerminalRunner, **SignatureVerification**, Logger). Team **436TYK8J6T** (Gamban LTD).
- **Distribution:** **Developer ID, DIRECT** (not App Store) — provisioning
  profile `ProfileDistributionType=DIRECT`, `ProvisionsAllDevices=true`,
  platform OSX, created 2025-01-24, long expiry (~2043).
- **Filtering = NetworkExtension *system extension*.** `networkextension`
  entitlement grants **all** provider types: `dns-proxy-systemextension`,
  `content-filter-provider-systemextension`, `app-proxy-provider-systemextension`,
  `packet-tunnel-provider-systemextension`, plus **`dns-settings`** and **`relay`**.
  → No `/etc/hosts`, no loopback resolver: the modern system-extension path.
  Host parsing via `URLComponents.host` suggests by-host content filtering.
- **Browser lockdown (the standout anti-bypass).** Strings expose
  **`ExtensionInstallBlocklist`** and **`valueForTrrModeTrustedResolverOnly`**
  + a `browserPolicy` component → Gamban writes **managed browser policies** to
  block VPN/proxy **extensions** and force **DoH to trusted-resolver-only**
  (i.e. neutralises Chrome/Firefox/Edge built-in DoH — the #1 desktop bypass).
  ⇒ **M-2**, the most important takeaway.
- **Push:** `aps-environment: production` (APNs) — remote signalling/config.
- **Anti-uninstall:** dedicated `GambanKit.UninstallerEntryPoint` with
  `signatureVerification` + `daemonManager` + `terminalRunner` (runs privileged
  steps). BUT the **EULA art. 11.5 explicitly concedes** "you … intentionally
  uninstall the Software" → Apple doesn't allow true prevention. ⇒ confirms
  **M-6** (heartbeat-gap) is the real lever, not on-device prevention.
- **Net for OFFBET:** seeds M-1 (NetworkExtension), **M-2 (browser policy —
  high value, adopt)**, M-3 (dns-settings), M-4 (Developer ID direct), M-5
  (signed uninstaller). Reaffirms heartbeat as the anti-uninstall backstop (M-6).
- **TODO on MacBook:** confirm which NEProvider is actually loaded
  (`systemextensionsctl list`), read the on-disk browser policy files it writes,
  check for a privileged helper / LaunchDaemon, and how it detects/repairs tamper.

### _<next app>_ — `<bundle id>` v? · audited YYYY-MM-DD
_Template — copy the Gamban block. Capture: distribution (App Store vs Developer
ID), filtering mechanism (NEProvider type / DNS-proxy / content-filter / hosts),
browser-policy injection, anti-uninstall, configuration profile, bypass vectors
closed (section 2), net-new backlog items._

---

## 6. Mac-side verification commands (run on the MacBook)

The Linux-side analysis (`strings` + decoded `embedded.provisionprofile`) can't
run Gatekeeper or read on-disk state. On the MacBook, per app (replace `PATH`):

```bash
# Signing, entitlements, distribution channel
codesign -dvvv --entitlements - --xml PATH.app
codesign -d -r-  PATH.app                 # designated requirement
# Gatekeeper verdict + notarization
spctl -a -vvv -t exec PATH.app            # "accepted, source=Notarized Developer ID" = notarized
xcrun stapler validate PATH.app           # is the notarization ticket stapled?
xcrun stapler validate PATH.dmg
# System extension actually loaded + its provider type
systemextensionsctl list
plutil -p "PATH.app/Contents/Library/SystemExtensions/"*.systemextension/Contents/Info.plist | grep -A3 NEProviderClasses
# Privileged helper / daemon (anti-uninstall)
ls -la "PATH.app/Contents/Library/LaunchServices" 2>/dev/null
ls /Library/LaunchDaemons /Library/LaunchAgents | grep -i <vendor>
# Browser managed-policy injection (the M-2 technique)
defaults read com.google.Chrome DnsOverHttpsMode 2>/dev/null
defaults read com.google.Chrome ExtensionInstallBlocklist 2>/dev/null
ls "/Library/Managed Preferences/"*/com.google.Chrome.plist /Library/Google/Chrome/policies/managed/ 2>/dev/null
cat /Applications/Firefox.app/Contents/Resources/distribution/policies.json 2>/dev/null
# Configuration profiles + DNS state
profiles list ; profiles show -type configuration
scutil --dns ; networksetup -getdnsservers Wi-Fi
```

**Gamban — to confirm on Mac:**
- [ ] `spctl` / `stapler validate` on `Gamban.app` + the `.dmg` → notarized & stapled?
- [ ] `systemextensionsctl list` → which NEProvider actually loads (dns-proxy vs content-filter)?
- [ ] which browser policies it writes, and their values (`DnsOverHttpsMode`, `ExtensionInstallBlocklist`)
- [ ] privileged helper / LaunchDaemon present? how the signed uninstaller runs privileged steps
- [ ] tamper behaviour: kill the extension / change DNS → does it re-assert + heartbeat-alert?
