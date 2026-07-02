import Foundation
import Network
import OffbetMatcher

/// Loopback DNS resolver (UDP). For each query:
///   - matcher says blocked  → answer **NXDOMAIN** (sinkhole, 100% local);
///   - otherwise             → forward the raw query to an upstream over **DoH**
///     (Quad9) and relay the raw response back.
/// Only non-blocked lookups leave the device, over encrypted DoH, carrying no
/// OFFBET identity (roadmap Decision 1 / ARCHITECTURE.md §3).
public final class Resolver {
    private let matcher: Matcher
    private let dohURL = URL(string: "https://dns.quad9.net/dns-query")!
    private let queue = DispatchQueue(label: "com.offbet.resolver")
    private let session = URLSession(configuration: .ephemeral)
    private var listener: NWListener?
    private var chronobetAllow: Set<String> = []

    public init(matcher: Matcher) { self.matcher = matcher }

    // MARK: lifecycle

    /// Bind UDP on 127.0.0.1:`port` (default 53; use a high port for unprivileged tests).
    public func start(port: UInt16 = 53) {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1",
                                                 port: NWEndpoint.Port(rawValue: port)!)
        do {
            let l = try NWListener(using: params)
            l.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
            l.stateUpdateHandler = { state in
                if case .failed(let e) = state { Log.error("Resolver listener failed: \(e)") }
            }
            l.start(queue: queue)
            listener = l
            Log.info("Resolver listening on 127.0.0.1:\(port) (UDP)")
        } catch {
            Log.error("Resolver bind failed on :\(port): \(error)")
        }
    }

    public func stop() { listener?.cancel(); listener = nil }

    public func setChronobetAllow(_ sites: [String]) { chronobetAllow = Set(sites.map { $0.lowercased() }) }
    public func clearChronobetAllow() { chronobetAllow.removeAll() }
    public var blocklistSize: Int { matcher.count }

    // MARK: per-query handling

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receiveMessage { [weak self] data, _, _, _ in
            guard let self = self, let query = data, !query.isEmpty else { conn.cancel(); return }
            self.process(query) { response in
                conn.send(content: response, completion: .contentProcessed { _ in conn.cancel() })
            }
        }
    }

    private func process(_ query: Data, _ reply: @escaping (Data) -> Void) {
        guard let q = Resolver.parseQuestion(query) else { forward(query, reply); return }
        let host = q.name.lowercased()
        let blocked = !chronobetAllow.contains(host) && matcher.isBlocked(host)
        if blocked {
            Log.info("BLOCK \(host)")
            reply(Resolver.nxdomain(for: query, questionEnd: q.end))
        } else {
            forward(query, reply)
        }
    }

    /// RFC 8484 DoH: POST the raw wire query, relay the raw wire response.
    private func forward(_ query: Data, _ reply: @escaping (Data) -> Void) {
        var req = URLRequest(url: dohURL)
        req.httpMethod = "POST"
        req.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        req.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        req.httpBody = query
        session.dataTask(with: req) { data, _, err in
            if let data = data, !data.isEmpty, err == nil { reply(data) }
            else { reply(Resolver.servfail(for: query)) }
        }.resume()
    }

    // MARK: DNS wire helpers

    /// Parse the (single) question: returns the QNAME and the byte offset just
    /// past QTYPE+QCLASS. Rejects compression pointers in the question (unusual).
    static func parseQuestion(_ msg: Data) -> (name: String, end: Int)? {
        let b = [UInt8](msg)
        guard b.count > 12 else { return nil }
        var i = 12
        var labels: [String] = []
        while i < b.count {
            let len = Int(b[i]); i += 1
            if len == 0 { break }
            if len & 0xC0 != 0 { return nil }
            guard i + len <= b.count else { return nil }
            labels.append(String(decoding: b[i..<i+len], as: UTF8.self))
            i += len
        }
        let end = i + 4 // QTYPE(2) + QCLASS(2)
        guard end <= b.count, !labels.isEmpty else { return nil }
        return (labels.joined(separator: "."), end)
    }

    /// Build an NXDOMAIN response: header (QR=1, RA=1, RCODE=3) + the original
    /// question, all answer/authority/additional counts zeroed.
    static func nxdomain(for query: Data, questionEnd: Int) -> Data {
        var r = [UInt8](query[0..<questionEnd])
        r[2] = 0x81            // QR=1, Opcode=0, RD=1
        r[3] = 0x83            // RA=1, RCODE=3 (NXDOMAIN)
        r[6] = 0; r[7] = 0     // ANCOUNT
        r[8] = 0; r[9] = 0     // NSCOUNT
        r[10] = 0; r[11] = 0   // ARCOUNT
        return Data(r)         // QDCOUNT (r[4..5]) preserved
    }

    /// SERVFAIL fallback if the upstream DoH call fails (don't fail open silently).
    static func servfail(for query: Data) -> Data {
        let end = parseQuestion(query)?.end ?? min(query.count, 12)
        var r = [UInt8](query[0..<end])
        if r.count >= 12 {
            r[2] = 0x81; r[3] = 0x82   // RCODE=2 (SERVFAIL)
            r[6] = 0; r[7] = 0; r[8] = 0; r[9] = 0; r[10] = 0; r[11] = 0
        }
        return Data(r)
    }
}
