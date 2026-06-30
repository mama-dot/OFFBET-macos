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
| M-2 | **Browser managed-policy injection** — write Chrome/Edge/Brave/Firefox managed policies to (a) **disable built-in DoH** or pin it (`DnsOverHttpsMode=off`), (b) **block VPN/proxy extensions** (`ExtensionInstallBlocklist`). Closes the #1 desktop bypass. | **Gamban** + **Safezino** do it (`DnsOverHttpsMode`/`ExtensionInstallBlocklist` managed prefs); GamBlock & BetBlocker lack it → browser-DoH bypass | 🔴 HIGH | ⬜ TODO |
| M-3 | **NEDNSSettings / DNS-proxy config** to own system DNS resolution (the `dns-settings` entitlement). | Gamban | 🟡 MED | ⬜ TODO |
| M-4 | **Developer ID direct distribution + notarization** (mirrors Windows direct-download). App Store later if useful. | Gamban (DIRECT profile) | 🔴 HIGH | ⬜ TODO |
| M-5 | **Signature-verified uninstaller + anti-tamper** on the app's own files; `SMAppService` keep-alive so quitting/unloading re-launches. (Apple concedes true anti-uninstall is impossible — see M-6.) | Gamban (`UninstallerEntryPoint`+`signatureVerification`) | 🟡 MED | ⬜ TODO |
| M-6 | **Companion heartbeat-gap → alert** — the real anti-uninstall lever on macOS (Apple forbids prevention; Gamban's own EULA concedes uninstall). Reuse the existing backend cron. | OFFBET-original (cross-platform) | 🔴 HIGH | ✅ exists backend-side |
| M-7 | **Standard (non-admin) account guidance** for true lockdown (Screen Time model) — onboarding nudge. | macOS constraint | 🟢 LOW | ⬜ TODO |
| M-8 | **Bypass-state detection** — watch DNS change, active 3rd-party VPN, extension disabled, profile removed → heartbeat `bypass_attempt`. | parallels Android C-6/C-11 | 🟡 MED | ⬜ TODO |
| M-9 | **pf anti-VPN firewall** — `pf` anchor that blocks/limits third-party VPN tunnels (utun*/ipsec*) so a NordVPN-style tunnel can't shadow filtering. Tradeoff: may break iCloud Private Relay (acceptable for a blocker). | Safezino (`pf` "anti-VPN v4") | 🟡 MED | ⬜ TODO |
| M-10 | **Immutable-flag anti-tamper** — `chflags noschg` (+ SIP-aware) on OFFBET's own config (hosts/pf/plists) so casual edits/deletes fail. Honest naming only (no Apple impersonation). | Safezino (`chflags noschg`) | 🟢 LOW | ⬜ TODO |
| M-11 | **In-browser blocking layer** — OFFBET browser extension + native-messaging host (Chrome/Edge/Firefox + Safari `.appex`), **force-installed & locked via managed policy** (M-2). DoH-immune (sees URLs in-browser) — complements the network filter for the cases DNS/NE can't see. OFFBET already markets an "Extension". | Cold Turkey | 🟡 MED | ⬜ TODO |

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

### Architecture landscape (4 competitors audited)

Four distinct models — pick OFFBET's deliberately:

| Competitor | Filtering engine | Distribution | Browser-DoH lockdown | Anti-VPN | 100% local | Robustness |
|------------|------------------|--------------|----------------------|----------|-----------|------------|
| **Gamban** v4 | **NetworkExtension** system extension (dns-proxy + content-filter) | Developer ID direct (notarized) | ✅ managed policies | via NE | ✅ | 🟢 strongest |
| **Safezino** v4 | **Shell-installed multi-daemon**: `/etc/hosts` + system DNS→own resolver + **`pf` anti-VPN** + browser policies | **`curl\|sudo bash`** (no app, **no notarization**) | ✅ managed policies | ✅ **pf blocks VPN tunnels** | ❌ own resolver | 🟢 aggressive (shady) |
| **GamBlock/Detoxify** v1 | **dnscrypt-proxy** root LaunchDaemon → own resolvers (server-side blocking) | Developer ID direct (Sparkle) | ❌ | ❌ | ❌ own resolver | 🟡 medium |
| **Freedom** | **Native app + SMJobBless privileged helper** → `/etc/hosts` (local) | Developer ID direct (Sparkle) | ❌ | ❌ | ✅ (hosts, nothing off-machine) | 🟡 productivity-grade (not adversarial) |
| **Cold Turkey** v4.9 | **In-browser: extension + Native Messaging Host** (Chrome/Edge/Firefox + Safari `.appex`) + app-block via KeepAlive LaunchAgent | Developer ID `.pkg` | 🟢 **immune** (blocks in-browser, DNS-independent) | ❌ (browser+app only, no network layer) | ✅ (in-browser) | 🟡 productivity, strong "locked mode" |
| **BetBlocker** v3.6 | **Electron + `sudo-prompt`** → writes `/etc/hosts` + system DNS | Developer ID direct (electron-updater) | ❌ | ❌ | partial (hosts) | 🔴 weakest |

Takeaways: (1) **NetworkExtension is the robust, clean target** (Gamban). (2)
**M-2 (browser-DoH lockdown) is mandatory** — Gamban & Safezino do it, the rest
are bypassable by browser DoH. (3) **pf anti-VPN** (Safezino) is a real desktop
technique worth stealing (M-9). (4) keep filtering **100% local** — Gamblock &
Safezino ship queries to their own resolvers (privacy + €cost); OFFBET's local
matcher is the edge.

**Anti-patterns to AVOID (seen in the wild):**
- ❌ **Impersonating Apple daemons** — Safezino installs `com.apple.systemcache.helperd` / `com.apple.dnscached` plists (stealth). Malware-like, breaks trust, risks flagging. OFFBET stays honestly named.
- ❌ **Config-supplied `sudo` exec** — BetBlocker runs `app_config.vpn_admin_rights[].exec` as root → remote-config = root-RCE class. OFFBET = fixed-purpose helper, never arbitrary exec.
- ❌ **DNS to own servers** — GamBlock/Safezino (privacy + scaling cost). OFFBET filters locally.

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

### GamBlock / "Detoxify" — `mac.com.familyfirst.ggg` v1.0.2 (2021) · audited 2026-06-30 (from `GGG.zip`, Linux-side)

> Long-running gambling-specific blocker (GamBlock, by "Family First"; Firebase
> project `gamblock`). Sample was a build codenamed **GGG**, but the daemon paths
> point to **`/Applications/Detoxify.app`** (a sibling/rebrand). **Opposite
> architecture to Gamban** — an older loopback-DNS model, no NetworkExtension.

- **Distribution:** **Developer ID, direct** — auto-update via **Sparkle**
  (`SUFeedURL = https://ggg-macos-distribution.s3.amazonaws.com/appcast.xml`,
  EdDSA-signed). Not App Store.
- **Shape:** menu-bar **agent** app (`LSUIElement`), Swift/AppKit, **gRPC+Protobuf**
  IPC to the daemon, **Firebase** backend. Main app is **sandboxed**
  (`com.apple.security.app-sandbox`) and has **no NetworkExtension entitlement**.
- **Filtering = `dnscrypt-proxy` as a root LaunchDaemon.** `DTXBurrowService` is
  the Go **dnscrypt-proxy** binary (strings: "dnscrypt-proxy is ready", DNS
  stamps, `blocked_names`, cloaking, DoH/DNSCrypt). LaunchDaemon `KeepAlive` +
  `RunAtLoad` runs it as root with `-config dnscrypt-proxy.toml`, listening on
  **`127.0.0.1:53`** (system DNS pinned to loopback). No `/etc/hosts`, no system extension.
- **Blocking is partly SERVER-SIDE.** The bundled toml sets
  `server_names = ['detoxify-primary','detoxify-secondary']` → it forwards over
  encrypted DNS to **GamBlock's own resolvers**, which do the gambling blocking
  (plus optional local cloaking/`blocked_names`). ⇒ **NOT 100% local**: their
  resolvers see the user's DNS queries (a privacy/RGPD cost, and a per-user
  server cost) — **the exact model OFFBET deliberately rejected.**
- **Weaknesses (= OFFBET's edges):**
  - **No browser-policy injection** found → **browser built-in DoH (Chrome/
    Firefox/Brave) bypasses it entirely** (those skip system DNS). ⇒ reinforces **M-2**.
  - **Server-side resolver** dependency → privacy + scaling cost. OFFBET's
    100%-local matcher is more private and **$0/scale** ⇒ a positioning edge.
  - **Anti-uninstall** rests only on the LaunchDaemon `KeepAlive`; the sandboxed
    agent can't defend itself. Delete the daemon/app and it's gone ⇒ heartbeat (M-6) is the lever.
- **Net for OFFBET:** validates the loopback-resolver model is shippable on mac,
  and that **dnscrypt-proxy** is a viable off-the-shelf engine (has blocklist/
  cloaking built in) — but **only if paired with M-2** (browser-DoH lockdown) and
  ideally kept **local** (don't adopt their custom-resolver/server-side model).
  Confirms M-4 (Developer ID direct + Sparkle-style updates) and M-6 (heartbeat).
- **TODO on MacBook:** `spctl`/`stapler` (notarized?), whether it **pins system
  DNS + watchdog** re-asserts on change, any `SMJobBless` helper to install the
  daemon, and confirm zero browser handling.

### BetBlocker — BetBlocker.app v3.6.3 (arm64) · audited 2026-06-30 (from `BetBlocker-3.6.3-arm64.dmg`, Linux-side)

> Free self-exclusion tool (charity, betblocker.org). The DMG is bzip2 UDIF;
> analysis from a partial bzip2 decompress of the image (the bundled JS is in
> clear). **Simplest of the three — Electron + privileged shell, no daemon, no NE.**

- **Stack:** **Electron 31.7.7** (Chrome 126), Angular/RxJS bundle. Signed
  **Developer ID Application: Radoslav Stoyanov (X237VLJ8WJ)** → direct
  distribution, auto-update via **electron-updater** (`app-update.yml`). Not App Store.
- **Filtering = `/etc/hosts` + system DNS, applied via privileged shell.** The
  renderer calls `window.require("sudo-prompt")` and runs
  `app_config.vpn_admin_rights[].exec` commands **as root** to `setupLocalHost()`
  (write blocked domains into **`/etc/hosts`**) and `setupDns()` (set system DNS).
  No NetworkExtension, no resolver daemon — static hosts + DNS, re-applied on launch.
- **Persistence:** `watchdog` / `relaunch` / keep-alive references (re-applies the
  hosts/DNS; no robust system extension). Has a **PIN/password** + the BetBlocker
  **"reminder" self-exclusion** period model.
- **Weaknesses (= OFFBET's edges):**
  - **No browser-DoH lockdown** → Chrome/Firefox/Brave built-in DoH bypasses
    `/etc/hosts` + system DNS entirely. ⇒ M-2 again.
  - **`/etc/hosts` only** = exact-domain matching, no suffix/wildcard, and the
    list it can write is limited — the exact model OFFBET-Windows rejected.
  - **Security smell:** running config-supplied `exec` strings with **`sudo`** is
    a root-RCE class risk if the config is remote/tampered. **OFFBET must not do
    this** (fixed-purpose privileged helper, never arbitrary exec).
- **Net for OFFBET:** confirms the **Electron shell** path (matches our plan) but
  is the weakest filtering model; reinforces M-1 (use NetworkExtension, not hosts)
  and M-2 (browser-DoH lockdown). Note the sudo-exec anti-pattern to avoid.
- **TODO on MacBook:** confirm notarization (`spctl`/`stapler`), whether a
  LaunchAgent/Daemon is installed for the watchdog, and exactly which `exec`
  commands run as root.

### Safezino — macOS "6-layer" v4 · audited 2026-06-30 (from public `install.sh`)

> French-market gambling blocker (the Android sibling is in the OFFBET-android
> doc). On macOS it ships **no signed app** — a `curl -fsSL …/install.sh | sudo
> bash` one-liner with a per-user token+session. The 60 KB script is fully
> readable → the most detailed source so far. **Most aggressive of the four.**

- **Distribution:** **`curl | sudo bash`** installer (token + session baked into
  the command; device-code/browser OAuth via `…/api/v1/auth/*`). **No `.app`, no
  Developer ID app, no notarization, no Gatekeeper** — pure root shell install.
- **6 layers (LaunchDaemons `com.safezino.{daemon,watchdog,firewall,block-reporter}`):**
  1. **`/etc/hosts`** — `0.0.0.0 domain`+`www`, **capped** at `MAX_HOSTS_ENTRIES` (rest via DNS).
  2. **System DNS → Safezino's own resolver `195.200.15.207`** (+ fallback Quad9
     `9.9.9.9`) on every network service via `networksetup -setdnsservers`. ⇒ **server-side blocking** (not local).
  3. **`pf` packet filter** — `/etc/pf.anchors/safezino` "GAMBLING FIREWALL v4
     (anti-VPN)" **blocks third-party VPN tunnels** (utun*/ipsec*) at packet level
     (knowingly breaks iCloud Private Relay). ⇒ **M-9**.
  4. **Browser managed policies** — `/Library/Managed Preferences/{Chrome,Brave,
     Edge,Firefox}.plist` with `DnsOverHttpsMode`/`DNSOverHTTPS` ⇒ **DoH lockdown (M-2)**.
  5. **Watchdog / "stealth guardians"** — re-arm DNS+hosts+pf on **STATE** (hosts
     markers + DNS pointing to Safezino), not file existence; "running but
     disarmed" → re-arm every ~2 min.
  6. **block-reporter** daemon — heartbeat/reporting to `…/api/v1`, renews refresh token.
- **Anti-tamper (aggressive):** **`chflags noschg`** (system immutable flag) on
  hosts, pf.conf, the anchor, all the daemon plists, the browser-policy plists and
  the scripts → can't be deleted/edited without clearing the flag first. Plus
  **two daemons disguised as Apple** (`com.apple.systemcache.helperd`,
  `com.apple.dnscached`). ⚠️ impersonation = anti-pattern (see above).
- **Anti-disable (v4, post-incident 2026-05-21):** the daemon **never self-wipes**
  on a subscription flag; only a local `disable_authorized` file (emitted by the
  backend **after a 24h-delay user-initiated uninstall flow**) permits teardown.
- **Net for OFFBET:** richest reference. **Steal:** pf anti-VPN (M-9), browser
  policy (M-2), immutable-flag anti-tamper (M-10), state-based watchdog re-arm.
  **Reject:** Apple-daemon impersonation, own-resolver DNS, and (probably) the
  no-notarization `curl|sudo` UX — a signed/notarized app is more trustworthy.
- **TODO on MacBook:** the exact pf rules, the browser-policy values
  (`DnsOverHttpsMode` = off/locked?), and the full 24h uninstall flow.

### Freedom — `to.freedom.*` (Eighty Percent Solutions Corp.) · audited 2026-06-30 (from `FreedomSetup.dmg`, Linux-side)

> Cross-platform **productivity** blocker (freedom.to) — focus sessions, not
> gambling-specific. Cited in the v8.2 PDF as proof that local filtering "doesn't
> send traffic off the machine". DMG is bzip2 UDIF; partial-decompress analysis.

- **Distribution:** Developer ID — **Eighty Percent Solutions Corporation** (team
  `G9…`), auto-update via **Sparkle**. Not App Store.
- **Shape:** native macOS app (the UI is **sandboxed**, `com.apple.security.app-sandbox`).
- **Filtering = privileged helper + `/etc/hosts`.** Installs a **SMJobBless /
  SMAppService privileged helper** (LaunchDaemon) that edits **`/etc/hosts`** (and
  touches `networksetup`) to block the user's chosen sites during sessions —
  **100% local** (their support confirms nothing leaves the machine). A legacy
  **`kext`** reference appears (older Freedom shipped a kernel content-filter; likely
  vestigial). **No NetworkExtension provider strings** found in the analyzed chunk.
- **Anti-bypass:** **none hardened** — no browser-DoH lockdown, no anti-VPN, hosts
  only. Freedom has a "Locked Mode" (can't stop a session early) but it's
  productivity-grade, not an adversarial self-exclusion fortress. DoH / changing
  DNS / another browser bypasses it.
- **UX:** a **real native app** (menu bar + windows) — the opposite of Safezino's
  invisible daemons; a good UX reference point.
- **Net for OFFBET:** validates the **SMJobBless/SMAppService privileged-helper**
  pattern (the mac analogue of the Windows C# SYSTEM service) **if** OFFBET takes
  the loopback/helper route instead of NetworkExtension — and that a clean app UX
  + Developer ID + Sparkle is the norm. But its hosts-only filtering is the weak
  tier (no M-2). Confirms 100%-local is a shipped, defensible model.
- **TODO on MacBook:** confirm the helper label + what it writes, whether the
  `kext` is actually loaded (likely not on modern macOS), notarization.

### Cold Turkey Blocker — `com.getcoldturkey.blocker` v4.9 · audited 2026-06-30 (from `Cold_Turkey_Mac_Installer.pkg`)

> Popular **productivity** blocker, famous for hard-to-bypass "locked"/"Frozen
> Turkey" modes. The `.pkg` is a xar archive — parsed in pure Python (TOC +
> PackageInfo + postinstall). **6th architecture, unique: in-browser, not network.**

- **Distribution:** Developer ID **`.pkg`** (auth=root, installs to `/Applications`).
  4 components: `Cold_Turkey_Blocker.pkg` (the app) + **`NMHChrome.pkg` /
  `NMHEdge.pkg` / `NMHFirefox.pkg`** (native-messaging hosts) + a bundled
  **`NMHSafari.appex`** Safari extension. Pkg ids `com.getcoldturkey.*`.
- **Website blocking = browser extension + Native Messaging Host (NMH).** It
  installs its own extension into Chrome/Edge/Firefox (+ Safari `.appex`); the
  extension blocks pages **inside the browser** and talks to the native app via
  native messaging. **No DNS, no `/etc/hosts`, no NetworkExtension, no pf.**
  - **DoH-immune by design**: the extension sees the URL in-browser regardless of
    how DNS resolves — the opposite answer to the bypass everyone else struggles with.
  - **Limits**: only the browsers it has an extension for; the user can disable the
    extension unless it's **force-installed via managed policy** (which Cold Turkey
    doesn't do — relies on "locked mode" instead). An unsupported browser isn't blocked.
- **App blocking + scheduling:** main app runs as a **`launchkeep.cold-turkey`
  LaunchAgent** (`KeepAlive`, `-agent`) — a *user* agent, not a root daemon. State
  in two SQLite DBs (`data-app.db`, `data-browser.db`).
- **Anti-bypass:** the renowned **"locked" block** (can't stop/uninstall until the
  timer ends) + KeepAlive relaunch. No network-layer hardening; relies on the
  lock + the user not killing the agent. Install scripts run as root and are a bit
  sloppy (`sudo echo > plist`) but **no config-supplied exec** (unlike BetBlocker).
- **Net for OFFBET:** introduces the **in-browser extension/NMH layer (M-11)** —
  the only model here that's **inherently DoH-proof**, and OFFBET already advertises
  an "Extension". Best combined with **M-2** (managed policy to *force-install +
  lock* the extension and block others). Confirms `.pkg` + LaunchAgent as a valid
  packaging path, and "locked mode" as a UX anti-bypass idea (cf. OFFBET PIN/delay).
- **TODO on MacBook:** confirm notarization (`spctl`/`stapler` on the pkg), how
  "locked mode" resists uninstall, and whether the Chromium extension also covers Brave/Arc.

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
