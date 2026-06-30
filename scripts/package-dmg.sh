#!/bin/bash
# Package OFFBET.app into a distributable .dmg. Run on macOS.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:-build/OFFBET.app}"
OUT="${2:-build/OFFBET.dmg}"

# TODO(mac): prefer `create-dmg` (brew) for a styled background + /Applications
# symlink. Minimal fallback:
echo "==> creating $OUT from $APP"
rm -f "$OUT"
hdiutil create -volname "OFFBET" -srcfolder "$APP" -ov -format UDZO "$OUT"
echo "==> done. Sign the dmg, then scripts/notarize.sh $OUT"
