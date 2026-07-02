#!/bin/bash
# Run the helper in USER mode (no root, no signing, no full Xcode) for local
# testing. Compiles with plain swiftc (CLT is enough) and runs the resolver on a
# high port + IPC on a /tmp socket.
#
#   Terminal 1:  bash scripts/dev-run.sh
#   Terminal 2:  dig @127.0.0.1 -p 15353 casino.com      # → NXDOMAIN (blocked)
#                dig @127.0.0.1 -p 15353 example.com     # → forwarded (real IP)
#                echo '{"cmd":"status"}' | nc -U /tmp/offbet-helper.sock
set -e
cd "$(dirname "$0")/.."

D="$(mktemp -d)"
for f in helper/Sources/OffbetHelperCore/*.swift; do
  grep -v 'import OffbetMatcher' "$f" > "$D/$(basename "$f")"   # core logic (Daemon incl.)
done
cp shared/Sources/OffbetMatcher/Matcher.swift "$D/"
grep -v 'import OffbetMatcher' helper/dev/main.swift > "$D/main.swift"

echo "==> compiling (swiftc) …"
swiftc -framework Network "$D"/*.swift -o /tmp/offbet-helper-dev

echo "==> running (Ctrl-C to stop). Test from another terminal:"
echo "      dig @127.0.0.1 -p 15353 casino.com     # NXDOMAIN"
echo "      dig @127.0.0.1 -p 15353 example.com    # forwarded"
echo "      echo '{\"cmd\":\"status\"}' | nc -U /tmp/offbet-helper.sock"
exec /tmp/offbet-helper-dev
