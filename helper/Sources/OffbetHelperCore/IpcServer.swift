import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Local IPC server for the Electron shell. Newline-delimited JSON over a
/// root-owned unix-domain socket (0600). Fixed verb set only — never executes
/// arbitrary commands (BetBlocker anti-pattern). See docs/IPC-CONTRACT.md.
final class IpcServer {
    private let resolver: Resolver
    private let pf: PfController
    private let policy: BrowserPolicy
    private let dns: DnsPinning
    private let pin: Pin
    private let heartbeat: Heartbeat

    /// Prod path is /var/run/offbet-helper.sock; overridable for unprivileged dev.
    private let socketPath: String

    init(resolver: Resolver, pf: PfController, policy: BrowserPolicy, dns: DnsPinning,
         pin: Pin, heartbeat: Heartbeat,
         socketPath: String = "/var/run/offbet-helper.sock") {
        self.resolver = resolver; self.pf = pf; self.policy = policy
        self.dns = dns; self.pin = pin; self.heartbeat = heartbeat
        self.socketPath = socketPath
    }

    /// Bind the unix socket and serve connections (blocking accept loop).
    func serve() {
        unlink(socketPath)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { Log.error("IpcServer socket() failed"); return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let cap = MemoryLayout.size(ofValue: addr.sun_path)
        withUnsafeMutablePointer(to: &addr.sun_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: cap) { dst in
                _ = strncpy(dst, socketPath, cap - 1)
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, len) }
        }
        guard bound == 0 else { Log.error("IpcServer bind() failed on \(socketPath)"); close(fd); return }
        chmod(socketPath, 0o600)
        guard listen(fd, 8) == 0 else { Log.error("IpcServer listen() failed"); close(fd); return }
        Log.info("IpcServer listening on \(socketPath)")

        while true {
            let conn = accept(fd, nil, nil)
            if conn < 0 { continue }
            handleClient(conn)
        }
    }

    private func handleClient(_ conn: Int32) {
        defer { close(conn) }
        var buf = [UInt8](repeating: 0, count: 8192)
        let n = read(conn, &buf, buf.count)
        guard n > 0 else { return }
        let line = Data(buf[0..<n])
        let response = dispatch(line)
        var out = response; out.append(0x0A) // newline-delimited
        out.withUnsafeBytes { _ = write(conn, $0.baseAddress, out.count) }
    }

    /// Parse `{ "cmd": ..., "args": {...} }` and route to the fixed handlers.
    private func dispatch(_ data: Data) -> Data {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cmd = obj["cmd"] as? String else {
            return json(["error": "bad_request"])
        }
        let args = obj["args"] as? [String: Any] ?? [:]
        return json(handle(cmd, args))
    }

    // Destructive verbs (disable/uninstall) are GATED (PIN / 24h authorization).
    // Internal (not private) so the unit tests can drive it via @testable import.
    func handle(_ cmd: String, _ args: [String: Any]) -> [String: Any] {
        switch cmd {
        case "status":
            return [
                "active": dns.isPinned() && pf.isActive(),
                "dnsPinned": dns.isPinned(),
                "pfActive": pf.isActive(),
                "browserPolicy": policy.isApplied(),
                "blocklistSize": resolver.blocklistSize,
                "lastHeartbeatOk": heartbeat.lastOk,
                "pinSet": pin.isSet(),
            ]
        case "enable":
            dns.pinToLoopback(); pf.installAntiVpnAnchor(); policy.apply()
            return ["ok": true]
        case "disable":
            guard let token = args["pinToken"] as? String, pin.verify(candidateHash: token) else {
                return ["error": "pin_required"]
            }
            dns.restoreUserDns(); pf.flush(); policy.remove()
            return ["ok": true]
        case "pin.set":
            guard let hash = args["hash"] as? String, !hash.isEmpty else {
                return ["error": "bad_request"]
            }
            // GATE: a PIN may only be set when none exists yet. Changing an
            // existing PIN must go through the 24h uninstall/recovery flow —
            // otherwise a user could just overwrite the PIN and defeat the
            // disable gate (the whole point of the PIN).
            guard !pin.isSet() else { return ["error": "pin_already_set"] }
            let hidden = args["hidden"] as? Bool ?? false
            let delay = Pin.ResetDelay(rawValue: (args["resetDelay"] as? String) ?? "h24") ?? .h24
            pin.setConfig(hash: hash, hidden: hidden, resetDelay: delay)
            return ["ok": true]
        case "pin.verify":
            let hash = args["candidateHash"] as? String ?? ""
            return ["ok": pin.verify(candidateHash: hash)]
        case "blocklist.refresh":
            heartbeat.sync()
            return ["ok": true, "size": resolver.blocklistSize]
        case "uninstall.request":
            let eligible = pin.requestUninstall()
            return ["ok": true, "eligibleAt": eligible.timeIntervalSince1970]
        default:
            return ["error": "unknown_cmd"]
        }
    }

    private func json(_ dict: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: dict)) ?? Data("{}".utf8)
    }
}
