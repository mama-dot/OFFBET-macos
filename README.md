# OFFBET macOS

Desktop client for OFFBET on macOS. Mirrors the **Windows** UX ("maximum webapp":
an Electron shell rendering `my.offbet.app`) and honors the roadmap v8.2 spirit
(100% local filtering, $0 DNS, offline PIN, Companion heartbeat, `POST /api/sync`,
freemium).

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** — the v1 design + decisions.
- **[MAC-BENCHMARK.md](./MAC-BENCHMARK.md)** — 6-competitor benchmark + backlog (M-1…M-11).
- **[BUILD.md](./BUILD.md)** — how to build/sign/notarize (on a Mac).
- **[docs/IPC-CONTRACT.md](./docs/IPC-CONTRACT.md)** — Electron ↔ helper protocol.

## Layout

```
electron/   Electron shell (TypeScript): loads my.offbet.app + native ON/OFF, PIN,
            Chronobet-timer windows + the helper IPC client.
helper/     Swift Package — the privileged root daemon (com.offbet.helper):
            loopback DNS resolver, pf anti-VPN, browser managed-policies,
            DNS pinning + watchdog, heartbeat, PIN, IPC server.
shared/     Swift Package — the OFFBET matcher (exact + suffix-walk + tokens +
            allowlist), shared with the iOS app.
scripts/    build / codesign / notarytool / dmg packaging.
.github/    macOS CI.
```

## Status

Scaffold only — every Swift file is a stub with `// TODO`. Builds on macOS 13+
with Xcode; the Swift parts do not compile on Linux. See BUILD.md.
