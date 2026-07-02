import XCTest
@testable import OffbetHelperCore

/// The resolver hand-rolls DNS wire parsing and the NXDOMAIN/SERVFAIL builders.
/// These are pure byte functions — perfect for unit tests, no socket/root needed.
final class ResolverWireTests: XCTestCase {
    /// Minimal DNS query: ID 0x1234, standard query, RD=1, one question A/IN.
    private func query(_ labels: [String]) -> Data {
        var b: [UInt8] = [0x12, 0x34, 0x01, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]
        for l in labels { b.append(UInt8(l.utf8.count)); b.append(contentsOf: Array(l.utf8)) }
        b.append(0)                                       // root label
        b.append(contentsOf: [0x00, 0x01, 0x00, 0x01])   // QTYPE=A, QCLASS=IN
        return Data(b)
    }

    func testParseQuestion() {
        let msg = query(["casino", "com"])
        let q = Resolver.parseQuestion(msg)
        XCTAssertEqual(q?.name, "casino.com")
        XCTAssertEqual(q?.end, msg.count)   // end sits just past QTYPE+QCLASS = full length
    }

    func testParseRejectsTooShort() {
        XCTAssertNil(Resolver.parseQuestion(Data([0, 1, 2, 3])))
    }

    func testParseRejectsCompressionPointer() {
        var b: [UInt8] = [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
        b.append(contentsOf: [0xC0, 0x0C])   // a compression pointer where a label is expected
        XCTAssertNil(Resolver.parseQuestion(Data(b)))
    }

    func testNxdomainEchoesIdAndSetsFlags() {
        let msg = query(["bet", "com"])
        let end = Resolver.parseQuestion(msg)!.end
        let r = [UInt8](Resolver.nxdomain(for: msg, questionEnd: end))
        XCTAssertEqual(r[0], 0x12); XCTAssertEqual(r[1], 0x34)  // transaction ID echoed
        XCTAssertEqual(r[2] & 0x80, 0x80)                       // QR = 1 (response)
        XCTAssertEqual(r[3] & 0x0F, 0x03)                       // RCODE = 3 (NXDOMAIN)
        XCTAssertEqual(r[6], 0); XCTAssertEqual(r[7], 0)        // ANCOUNT = 0
        XCTAssertEqual(r.count, end)                            // header + question only
    }

    func testServfailSetsFlags() {
        let r = [UInt8](Resolver.servfail(for: query(["x", "com"])))
        XCTAssertEqual(r[2] & 0x80, 0x80)   // QR = 1
        XCTAssertEqual(r[3] & 0x0F, 0x02)   // RCODE = 2 (SERVFAIL)
    }
}
