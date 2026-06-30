# OFFBET macOS — Architecture (v1)

Decision doc for the macOS app. Honors **two hard constraints**:

1. **Same UX as Windows** — an **Electron shell** rendering the existing web app
   (`my.offbet.app`): account, settings, Companion, PIN config, Chronobet,
   subscription. Zero new screens ("maximum webapp", roadmap Decision 2).
2. **The roadmap v8.2 spirit** — **100% local filtering** ($0 DNS, nothing leaves
   the device, RGPD-clean), **PIN verified offline**, **Companion heartbeat**,
   the single **`POST /api/sync`** endpoint, **freemium** (filtering never cut).

Informed by the 6-competitor benchmark in [MAC-BENCHMARK.md](./MAC-BENCHMARK.md)
(M-1…M-11).

---

## 1. The key reconciliation (read first)

Two facts force the shape of this design:

- **Electron rules out a NetworkExtension *system extension*.** Gamban's model
  (the most robust) needs a **native Swift `.app`** to host the system extension.
  We keep Electron (Windows parity, per constraint 1) → we **cannot** ship a
  NE system extension in v1. We use a **privileged helper daemon** instead.
- **`/etc/hosts` (the v8.2 PDF plan) is too weak.** Windows itself already moved
  *past* hosts to a **loopback DNS resolver** carrying the full matcher. macOS
  mirrors **that**, not the PDF's hosts file.

> **v1 engine = Electron shell + a privileged helper daemon running a loopback
> DNS resolver (the Windows matcher, ported), 100% local — hardened with pf
> (anti-VPN) and browser managed-policies (anti-DoH).**
> This is the Windows architecture, ported to macOS, plus the desktop anti-bypass
> layers the benchmark proved are mandatory.

NetworkExtension (Gamban-style) and an in-browser extension (Cold Turkey-style,
M-11) are **v2 options** — see §8.

---

## 2. Components

```
┌─────────────────────────────────────────────────────────────┐
│ OFFBET.app  (Electron — same shell as Windows)              │
│  ├─ WKWebView/Chromium → my.offbet.app  (account, settings, │
│  │     Companion, PIN config, Chronobet, Stripe)            │
│  └─ native-feel local screens: ON/OFF, PIN, Chronobet timer │
│         (status that must work offline / be non-bypassable) │
│              │ local IPC (XPC / unix socket, authenticated)  │
└──────────────┼──────────────────────────────────────────────┘
               ▼
┌─────────────────────────────────────────────────────────────┐
│ com.offbet.helper  (privileged LaunchDaemon, root)          │
│  Installed via SMAppService (modern) / SMJobBless (legacy)   │
│  ├─ Loopback DNS resolver  127.0.0.1:53  (+ [::1]:53)        │
│  │    matcher: exact + suffix-walk + tokens + allowlist      │
│  │    (ported from Android Kotlin / Windows C#)              │
│  │    non-blocked queries → upstream DoH (Quad9) — LOCAL     │
│  ├─ pins system DNS → loopback (networksetup/SCDynamicStore) │
│  │    + watchdog re-asserts on change (state-based)          │
│  ├─ pf anchor "offbet" — anti-VPN (M-9): block 3rd-party     │
│  │    tunnels (utun*/ipsec*) that would shadow filtering     │
│  ├─ browser managed-policies (M-2): disable built-in DoH +   │
│  │    block VPN/proxy extensions (Chrome/Edge/Brave/Firefox) │
│  ├─ blocklist refresh from /api/sync (cached locally)        │
│  ├─ PIN hash (local, offline-verified) + 24h-uninstall flow  │
│  └─ heartbeat POST /api/sync (5 min) → Companion             │
└─────────────────────────────────────────────────────────────┘
        backend: Next.js /api/sync on EC2 · Firebase Auth · AWS SNS (SMS)
```

- **Shared core:** the matcher + blocklist + PIN + heartbeat logic is the **same
  model as Windows**. Implement the helper in **Swift** (so it can share a Swift
  Package with iOS, per roadmap Decision 6) **or** Go/Rust (to share the resolver
  with Windows). Decision pending — see §9.
- **IPC:** Electron ↔ helper over an authenticated local channel (XPC via a tiny
  Swift broker, or a unix socket with a per-install secret). The helper never
  executes anything the renderer sends as a command (avoid the BetBlocker
  sudo-exec anti-pattern).

---

## 3. Filtering engine — 100% local (roadmap Decision 1)

- Loopback resolver answers from the **local matcher**; only *cache-miss,
  non-blocked* lookups are forwarded upstream (encrypted DoH to a public
  resolver). **Which gambling sites the user attempts never leaves to an OFFBET
  server** → $0 DNS, no per-user scaling cost, RGPD-clean. (Contrast: GamBlock &
  Safezino send DNS to *their* resolvers — rejected.)
- **Resists 3rd-party VPN** better than external DNS (the loopback is the system
  resolver), and pf (§4) blocks the tunnels that could still shadow it.
- **Sinkhole (v2):** the helper serves a local "Blocked by OFFBET" page on
  127.0.0.1 instead of a bare browser error.

---

## 4. Anti-bypass layers (PDF's 4 layers, upgraded by the benchmark)

| Layer | Mechanism | Source |
|-------|-----------|--------|
| 1. Filter | loopback DNS resolver (local matcher) | roadmap + Windows |
| 2. Desktop bypass closers | **pf anti-VPN (M-9)** + **browser DoH/extension lockdown (M-2)** | Safezino, Gamban |
| 3. Anti-kill | root LaunchDaemon + **state-based watchdog re-arm** + optional `chflags` immutability (M-10) | Safezino (clean) |
| 4. Imparable | **PIN (offline) + 24h-delay uninstall + heartbeat-gap → Companion SMS** | roadmap |

**M-2 is mandatory** — without disabling browser built-in DoH, Chrome/Firefox/
Brave bypass any DNS-based filter (proven by GamBlock/BetBlocker). **M-9** is the
only real answer to a user enabling NordVPN etc.

---

## 5. Native vs WebView split (roadmap Decision 2)

| Screen / function | Type | Why |
|---|---|---|
| Onboarding, login, account, settings, Stripe, Companion config, Chronobet history, custom domains | **WebView** (my.offbet.app) | one UI, deployed in 5 min, no app-store round-trip |
| ON/OFF protection toggle, PIN entry, Chronobet timer, protection status | **Native (Electron local)** | must work offline + be non-bypassable; talks to the helper |

---

## 6. Distribution & signing

- **Developer ID, direct download** from `offbet.app` — signed `.dmg`/`.pkg`,
  **notarized by Apple** (required: a privileged helper / non-sandboxed app won't
  run otherwise). Auto-update via Sparkle or electron-updater. Mirrors the Windows
  direct-download model.
- **Not the Mac App Store** for v1 — its sandbox forbids the privileged helper,
  pf, and browser managed-policies.
- **Not** `curl | sudo bash` (Safezino) — a signed/notarized installer is far more
  trustworthy for a vulnerable audience.

---

## 7. Deliberately rejected (anti-patterns from the benchmark)

- ❌ **Impersonating Apple daemons** (`com.apple.*`) — Safezino does this; it's
  malware-like and breaks trust. OFFBET daemons are honestly named `com.offbet.*`.
- ❌ **Config-supplied `sudo` exec** (BetBlocker) — root-RCE class. The helper has
  a fixed, audited command surface; it never runs renderer/server-supplied shell.
- ❌ **DNS to our own servers** (GamBlock/Safezino) — breaks 100%-local + RGPD.
- ❌ **`/etc/hosts`-only** (BetBlocker/Freedom) — exact-match only, defeated by DoH.

---

## 8. Backlog mapping (from MAC-BENCHMARK.md) — v1 vs later

| ID | Item | v1? |
|----|------|-----|
| M-2 | Browser DoH + extension lockdown (managed policies) | ✅ v1 (mandatory) |
| M-9 | pf anti-VPN firewall | ✅ v1 |
| M-6 | Companion heartbeat-gap → SMS | ✅ v1 (backend exists) |
| M-4 | Developer ID direct + notarization | ✅ v1 |
| M-3 | Own system DNS (loopback resolver) | ✅ v1 (local, not own server) |
| M-10 | Immutable-flag anti-tamper (`chflags`) | 🟡 v1.x |
| M-5 | Signed/verified uninstaller + keep-alive | 🟡 v1.x |
| M-1 | NetworkExtension system extension | ⬜ v2 (needs native Swift app — drops Electron) |
| M-11 | In-browser extension + native-messaging host | ⬜ v2 (OFFBET already markets an "Extension") |
| M-7 | Standard-account / MDM lockdown guidance | ⬜ v2 |
| M-8 | Bypass-state detection (DNS/VPN/profile) | 🟡 v1.x |

---

## 9. Open questions (decide before build)

1. **Helper language:** Swift (shares a Swift Package with iOS, roadmap Decision 6)
   vs Go/Rust (shares the resolver core with Windows). Leaning Swift for
   iOS-parity; the resolver is small to port.
2. **DoH upstream** for non-blocked queries: Quad9 / Cloudflare / configurable?
3. **pf vs the user's own pf rules** — coexist via a dedicated anchor; document the
   iCloud Private Relay break (acceptable, like Safezino).
4. **Reuse the Windows matcher** as a shared lib vs reimplement — measure effort.
5. Eventually: ship the **NetworkExtension v2** (native Swift) and/or the
   **browser extension (M-11)** as added layers, keeping Electron as the shell.
