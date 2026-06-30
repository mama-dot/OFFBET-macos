#!/bin/bash
# Codesign OFFBET.app + the embedded helper with the Developer ID Application cert.
# Hardened runtime is required for notarization. Run on macOS.
set -euo pipefail

APP="${1:-build/OFFBET.app}"
IDENTITY="${OFFBET_SIGN_IDENTITY:?set OFFBET_SIGN_IDENTITY=\"Developer ID Application: … (TEAMID)\"}"

# Sign inside-out: helper + frameworks first, then the app bundle.
# TODO(mac): provide entitlements plists:
#   helper.entitlements  — (no app-sandbox; it's a Developer ID daemon)
#   app.entitlements     — hardened runtime, no sandbox
echo "==> signing helper + nested code"
find "$APP/Contents" -type f \( -name "*.dylib" -o -path "*/MacOS/*" \) -print0 \
  | xargs -0 -I{} codesign --force --options runtime --timestamp --sign "$IDENTITY" "{}"

echo "==> signing app bundle"
codesign --force --options runtime --timestamp \
  --entitlements packaging/app.entitlements \
  --sign "$IDENTITY" "$APP"

codesign -dvvv "$APP" || true
echo "==> done. Next: scripts/notarize.sh"
