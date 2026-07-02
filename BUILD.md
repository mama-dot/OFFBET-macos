# Building OFFBET macOS

> Runs on **macOS 12+ with Xcode (or Command Line Tools)**. Dev works on Monterey
> (Swift 5.7); release/CI on `macos-14`. Swift helper, codesign, pf and
> notarization cannot run on Linux.
>
> **Install model:** a Developer ID **`.pkg`** whose `packaging/pkg-scripts/postinstall`
> installs + loads the privileged LaunchDaemon (`com.offbet.helper`). This works on
> macOS 12+ (no SMAppService, which is 13-only). See `scripts/package-pkg.sh`.
>
> **Local test without Xcode/SwiftPM:** the matcher + helper compile with plain
> `swiftc` (CLT-only) — see the recipes in each module's tests and the session
> notes. XCTest (`swift test`) needs full Xcode → runs on CI (`macos-14`).

## Prerequisites

1. **Apple Developer Program** ($99/yr). You need:
   - Team ID
   - **Developer ID Application** cert (signs the .app + helper)
   - **Developer ID Installer** cert (signs the .pkg, if used)
   - A **notarytool** credential: an App Store Connect API key *or* an
     app-specific password. Store it in the keychain:
     `xcrun notarytool store-credentials offbet-notary --apple-id … --team-id … --password …`
2. **Xcode 15+** and command-line tools (`xcode-select --install`).
3. **Node 20+** for the Electron shell.

## Build steps (high level)

```bash
# 1. Shared matcher — tests on CI (Xcode); locally: swiftc (see notes)
cd shared && swift test && cd ..          # (needs full Xcode)

# 2. Privileged helper daemon
cd helper && swift build -c release && cd ..

# 3. Electron shell (full install to get the electron runtime binary)
cd electron && npm install && npm run build && cd ..

# 4. One-shot: build helper + app, bundle, sign, and build the installer .pkg
export OFFBET_SIGN_IDENTITY="Developer ID Application: … (TEAMID)"
export OFFBET_INSTALLER_IDENTITY="Developer ID Installer: … (TEAMID)"
bash scripts/package-pkg.sh               # → build/OFFBET-Installer.pkg

# 5. Notarize + staple
xcrun notarytool store-credentials offbet-notary --apple-id … --team-id … --password …
bash scripts/notarize.sh build/OFFBET-Installer.pkg
```

electron-builder signing can alternatively be driven by env
(`CSC_LINK`/`CSC_KEY_PASSWORD`, `APPLE_ID`/`APPLE_APP_SPECIFIC_PASSWORD`/`APPLE_TEAM_ID`).
Everything above is ready — it only needs the **Developer ID certs** (Apple account).

## Entitlements the helper needs (NOT App Store)

- run as a **root LaunchDaemon** via **SMAppService** (macOS 13+).
- write `/etc/pf.anchors/offbet` + `pfctl` (anti-VPN).
- write `/Library/Managed Preferences/*` browser policies (DoH off + extension block).
- set system DNS (`SCDynamicStore` / `networksetup`) to the loopback resolver.
- bind `127.0.0.1:53`.

These require **Developer ID direct distribution + notarization** — the Mac App
Store sandbox forbids them (see ARCHITECTURE.md §6).

## Verify on device

```bash
spctl -a -vvv -t exec /Applications/OFFBET.app          # Notarized?
xcrun stapler validate /Applications/OFFBET.app
scutil --dns | grep -A2 resolver                        # DNS pinned to loopback?
sudo pfctl -a offbet -s rules                           # pf anti-VPN active?
defaults read com.google.Chrome DnsOverHttpsMode        # browser DoH off?
```
