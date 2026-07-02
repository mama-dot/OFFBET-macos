import XCTest
@testable import OffbetHelperCore

/// The PIN is the core of the "user can't disable on impulse" guarantee, so its
/// storage, verification, and 24h-recovery timing get direct coverage.
final class PinTests: XCTestCase {
    private func tmpPin() -> Pin {
        Pin(path: NSTemporaryDirectory() + "offbet-pin-\(UUID().uuidString).json")
    }

    func testUnsetByDefault() {
        let p = tmpPin()
        XCTAssertFalse(p.isSet())
        XCTAssertFalse(p.verify(candidateHash: "anything"))
    }

    func testSetThenVerify() {
        let p = tmpPin()
        p.setConfig(hash: "abc123", hidden: false, resetDelay: .h24)
        XCTAssertTrue(p.isSet())
        XCTAssertTrue(p.verify(candidateHash: "abc123"))
        XCTAssertFalse(p.verify(candidateHash: "abc124"))
    }

    func testSetPersistsAcrossInstances() {
        let path = NSTemporaryDirectory() + "offbet-pin-\(UUID().uuidString).json"
        Pin(path: path).setConfig(hash: "persist", hidden: true, resetDelay: .h48)
        XCTAssertTrue(Pin(path: path).verify(candidateHash: "persist"))
    }

    func testConstantTimeEquals() {
        XCTAssertTrue(Pin.constantTimeEquals("deadbeef", "deadbeef"))
        XCTAssertFalse(Pin.constantTimeEquals("deadbeef", "deadbeee"))
        XCTAssertFalse(Pin.constantTimeEquals("short", "longer"))
    }

    func testDelaySeconds() {
        XCTAssertEqual(Pin.delaySeconds(.h12), 12 * 3600)
        XCTAssertEqual(Pin.delaySeconds(.h24), 24 * 3600)
        XCTAssertEqual(Pin.delaySeconds(.h48), 48 * 3600)
    }

    func testUninstallDelayEligibility() {
        let p = tmpPin()
        p.setConfig(hash: "h", hidden: false, resetDelay: .h24)
        XCTAssertFalse(p.uninstallEligible())                       // not requested yet
        let eligibleAt = p.requestUninstall()
        XCTAssertGreaterThan(eligibleAt.timeIntervalSinceNow, 23 * 3600)  // ~24h out
        XCTAssertFalse(p.uninstallEligible())                       // still inside the delay
    }

    func testLifetimeDelayNeverEligible() {
        let p = tmpPin()
        p.setConfig(hash: "h", hidden: false, resetDelay: .lifetime)
        _ = p.requestUninstall()
        XCTAssertFalse(p.uninstallEligible())
    }
}
