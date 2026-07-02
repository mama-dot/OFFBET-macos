# Electron ↔ Helper IPC contract

The Electron shell (unprivileged, user session) talks to **com.offbet.helper**
(privileged root daemon) over a **local authenticated channel**:

- Transport: a unix-domain socket the helper owns at
  `/var/run/offbet-helper.sock` (root-owned, 0600), **or** an XPC service via a
  tiny Swift broker. v1 default: unix socket + a per-install shared secret handed
  over at first launch.
- Encoding: newline-delimited JSON (`{ "cmd": ..., "args": {...}, "nonce": ... }`).
- The helper **never** executes arbitrary commands from the shell — only the
  fixed verbs below (avoids the BetBlocker sudo-exec anti-pattern).

## Commands (shell → helper)

| cmd | args | effect | returns |
|-----|------|--------|---------|
| `status` | — | read protection state | `{ active, dnsPinned, pfActive, browserPolicy, blocklistSize, lastHeartbeatOk }` |
| `enable` | — | arm: pin DNS, load pf, write browser policies, start resolver | `{ ok }` |
| `disable` | `{ pinToken }` | **gated** — only with a valid PIN token (offline-verified) or after the 24h uninstall flow | `{ ok }` or `{ error: "pin_required" }` |
| `pin.set` | `{ hash, hidden, resetDelay }` | store PIN config locally (Keychain) | `{ ok }` |
| `pin.verify` | `{ candidateHash }` | offline verify | `{ ok }` |
| `blocklist.refresh` | — | force a `/api/sync` pull | `{ ok, size }` |
| `uninstall.request` | — | start the **24h-delay** uninstall flow (backend authorizes) | `{ ok, eligibleAt }` |

## Events (helper → shell, pushed)

| event | payload | when |
|-------|---------|------|
| `state` | same as `status` | on any change |
| `incident` | `{ kind: "block"\|"vpn"\|"dns_change"\|"pin_fail", detail }` | on detection (also heartbeat'd) |

## Heartbeat (helper → backend, not shell)

`POST /api/sync` every 5 min with `os=macOS`, `protection_active`,
`blocked_attempts[]`, `bypass_attempt`, `pin_failed_attempts`, `pin_hash`,
`custom_domains`. Returns blocklist + premium + companion (same contract as
Android/Windows).

## Security notes

- Shell authenticates to the helper with the per-install secret; the helper
  rejects unsigned/unknown callers (verify the calling binary's code signature
  where possible).
- `disable`/`uninstall` are the only destructive verbs and are **gated** (PIN or
  24h-delay backend authorization). The helper never trusts a bare `disable`.
