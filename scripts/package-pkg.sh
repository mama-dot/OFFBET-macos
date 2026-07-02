#!/bin/bash
# Build the distributable OFFBET installer .pkg (Developer ID + notarized).
# Runs on macOS with Xcode + Node + electron binary + the Developer ID certs.
# Universal on macOS 12+ (installs the LaunchDaemon via pkg-scripts/postinstall —
# no SMAppService, so it works on Monterey too).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
STAGE="build/stage"
OUT="build"
mkdir -p "$OUT"

echo "==> 1. Build helper daemon (release)"
( cd helper && swift build -c release )
HELPER="helper/.build/release/OffbetHelper"

echo "==> 2. Build Electron app (electron-builder --dir)"
# needs the electron binary (npm install WITHOUT --ignore-scripts) — see BUILD.md
( cd electron && npm run pack )
APP="$(/usr/bin/find electron/release -maxdepth 3 -name 'OFFBET.app' | head -1)"
[ -n "$APP" ] || { echo "OFFBET.app not found (electron-builder pack failed)"; exit 1; }

echo "==> 3. Bundle helper + LaunchDaemon into the app Resources"
cp "$HELPER" "$APP/Contents/Resources/OffbetHelper"
cp helper/Resources/com.offbet.helper.plist "$APP/Contents/Resources/"

echo "==> 4. Codesign the app (hardened runtime)"
# electron-builder can also sign; do it here for the bundled helper too.
: "${OFFBET_SIGN_IDENTITY:?set OFFBET_SIGN_IDENTITY=\"Developer ID Application: … (TEAMID)\"}"
codesign --force --options runtime --timestamp --sign "$OFFBET_SIGN_IDENTITY" "$APP/Contents/Resources/OffbetHelper"
codesign --force --options runtime --timestamp \
  --entitlements electron/build/entitlements.mac.plist \
  --deep --sign "$OFFBET_SIGN_IDENTITY" "$APP"

echo "==> 5. Stage + build component pkg (postinstall installs the daemon)"
rm -rf "$STAGE"; mkdir -p "$STAGE/Applications"
cp -R "$APP" "$STAGE/Applications/"
chmod +x packaging/pkg-scripts/postinstall
pkgbuild --root "$STAGE" --install-location / \
  --scripts packaging/pkg-scripts \
  --identifier com.offbet.mac --version "$VERSION" \
  "/tmp/offbet-component.pkg"

echo "==> 6. productbuild (signed if OFFBET_INSTALLER_IDENTITY set)"
productbuild --package "/tmp/offbet-component.pkg" \
  ${OFFBET_INSTALLER_IDENTITY:+--sign "$OFFBET_INSTALLER_IDENTITY"} \
  "$OUT/OFFBET-Installer.pkg"

echo "==> done → $OUT/OFFBET-Installer.pkg   (next: scripts/notarize.sh $OUT/OFFBET-Installer.pkg)"
