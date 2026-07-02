import XCTest
@testable import OffbetHelperCore
import OffbetMatcher

/// Drives the IPC verb dispatcher directly (IpcServer.handle) to lock down the
/// security-critical gating: disable needs a valid PIN, and pin.set can never
/// overwrite an existing PIN (which would defeat the disable gate).
final class IpcDispatchTests: XCTestCase {
    private func tmpPin() -> Pin {
        Pin(path: NSTemporaryDirectory() + "offbet-pin-\(UUID().uuidString).json")
    }
    private func server(pin: Pin) -> IpcServer {
        IpcServer(resolver: Resolver(matcher: Matcher()),
                  pf: PfController(), policy: BrowserPolicy(),
                  dns: DnsPinning(), pin: pin, heartbeat: Heartbeat())
    }

    func testUnknownCmd() {
        XCTAssertEqual(server(pin: tmpPin()).handle("nope", [:])["error"] as? String, "unknown_cmd")
    }

    func testStatusShape() {
        let r = server(pin: tmpPin()).handle("status", [:])
        XCTAssertNotNil(r["active"])
        XCTAssertNotNil(r["pinSet"])
        XCTAssertNotNil(r["blocklistSize"])
    }

    func testStatusReportsPinSet() {
        let pin = tmpPin()
        XCTAssertEqual(server(pin: pin).handle("status", [:])["pinSet"] as? Bool, false)
        pin.setConfig(hash: "h", hidden: false, resetDelay: .h24)
        XCTAssertEqual(server(pin: pin).handle("status", [:])["pinSet"] as? Bool, true)
    }

    func testDisableRequiresPin() {
        XCTAssertEqual(server(pin: tmpPin()).handle("disable", [:])["error"] as? String, "pin_required")
    }

    func testDisableRejectsWrongPin() {
        let pin = tmpPin()
        pin.setConfig(hash: "correct", hidden: false, resetDelay: .h24)
        let r = server(pin: pin).handle("disable", ["pinToken": "wrong"])
        XCTAssertEqual(r["error"] as? String, "pin_required")
    }

    func testPinSetRejectsEmpty() {
        XCTAssertEqual(server(pin: tmpPin()).handle("pin.set", ["hash": ""])["error"] as? String, "bad_request")
    }

    func testPinSetOnlyWhenUnset() {
        let pin = tmpPin()
        XCTAssertEqual(server(pin: pin).handle("pin.set", ["hash": "h1"])["ok"] as? Bool, true)
        XCTAssertTrue(pin.isSet())
        // A second set must be refused — otherwise a user could overwrite the
        // PIN and bypass the disable gate entirely.
        XCTAssertEqual(server(pin: pin).handle("pin.set", ["hash": "h2"])["error"] as? String, "pin_already_set")
        XCTAssertTrue(pin.verify(candidateHash: "h1"))   // original PIN unchanged
        XCTAssertFalse(pin.verify(candidateHash: "h2"))
    }

    func testPinVerify() {
        let pin = tmpPin()
        pin.setConfig(hash: "xyz", hidden: false, resetDelay: .h24)
        XCTAssertEqual(server(pin: pin).handle("pin.verify", ["candidateHash": "xyz"])["ok"] as? Bool, true)
        XCTAssertEqual(server(pin: pin).handle("pin.verify", ["candidateHash": "no"])["ok"] as? Bool, false)
    }

    func testBadRequestOnMalformedIsHandledByDispatchNotHandle() {
        // handle() only sees already-parsed verbs; unknown ones are rejected.
        XCTAssertEqual(server(pin: tmpPin()).handle("", [:])["error"] as? String, "unknown_cmd")
    }
}
