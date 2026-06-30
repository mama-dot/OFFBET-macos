#!/bin/bash
# Notarize + staple. Requires a stored notarytool credential (see BUILD.md):
#   xcrun notarytool store-credentials offbet-notary --apple-id … --team-id … --password …
set -euo pipefail

ARTIFACT="${1:-build/OFFBET.dmg}"   # notarize the .dmg (or a zip of the .app)
PROFILE="${OFFBET_NOTARY_PROFILE:-offbet-notary}"

echo "==> submitting $ARTIFACT to Apple notary"
xcrun notarytool submit "$ARTIFACT" --keychain-profile "$PROFILE" --wait

echo "==> stapling"
xcrun stapler staple "$ARTIFACT"
xcrun stapler validate "$ARTIFACT"
echo "==> notarized + stapled."
