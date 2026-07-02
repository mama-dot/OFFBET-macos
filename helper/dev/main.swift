import Foundation
import OffbetMatcher

// USER-MODE dev entry (no root, no signing). Runs the resolver on a high port
// and the IPC server on a /tmp socket, so you can exercise the filtering engine
// + IPC locally. The real daemon (helper/Sources/OffbetHelper/main.swift) binds
// :53 and pins system DNS, which need root. Launched via scripts/dev-run.sh.
let m = Matcher()
m.replace(domains: ["casino.com", "bet365.com", "pokerstars.com"],
          tokens: ["betclic"], allowlist: [])
let resolver = Resolver(matcher: m)
resolver.start(port: 15353)

let ipc = IpcServer(resolver: resolver, pf: PfController(), policy: BrowserPolicy(),
                    dns: DnsPinning(), pin: Pin(), heartbeat: Heartbeat(resolver: resolver),
                    socketPath: "/tmp/offbet-helper.sock")
DispatchQueue.global().async { ipc.serve() }

print("OFFBET helper (dev) — DNS 127.0.0.1:15353 · IPC /tmp/offbet-helper.sock")
RunLoop.main.run()
