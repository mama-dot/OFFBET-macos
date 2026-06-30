#!/bin/bash
# Build everything (run on macOS 13+ with Xcode). See BUILD.md.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> shared matcher: test"
( cd shared && swift test )

echo "==> helper daemon: build (release)"
( cd helper && swift build -c release )

echo "==> electron shell: install + build"
( cd electron && npm install && npm run build )

echo "==> TODO: assemble OFFBET.app (shell + helper + Info.plist + entitlements),"
echo "    then scripts/codesign.sh && scripts/notarize.sh && scripts/package-dmg.sh"
