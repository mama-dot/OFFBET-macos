# Building OFFBET macOS

> Everything here runs on **macOS 13+ with Xcode**. The Swift helper, codesign,
> pf and notarization cannot run on Linux. This repo is scaffold + TODOs.

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
# 1. Shared matcher (Swift Package) — unit-tested, no entitlements
cd shared && swift test && cd ..

# 2. Privileged helper daemon (Swift)
cd helper && swift build -c release && cd ..
# (Xcode target needed for the SMAppService daemon bundle + entitlements)

# 3. Electron shell
cd electron && npm install && npm run build && cd ..

# 4. Assemble OFFBET.app:
#    OFFBET.app/Contents/MacOS/<electron>            (the shell)
#    OFFBET.app/Contents/Library/LaunchDaemons/      (com.offbet.helper)
#    + the helper binary under Contents/MacOS/ or a registered SMAppService daemon

# 5. Sign + notarize + package
bash scripts/codesign.sh
bash scripts/notarize.sh
bash scripts/package-dmg.sh
```

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
