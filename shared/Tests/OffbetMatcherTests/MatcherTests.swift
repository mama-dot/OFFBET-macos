import XCTest
@testable import OffbetMatcher

final class MatcherTests: XCTestCase {
    private func m() -> Matcher {
        let m = Matcher()
        m.replace(
            domains: ["casino.com", "bet365.com"],
            tokens: ["pokerstars"],
            allowlist: ["help.casino.com"]
        )
        return m
    }

    func testExact() { XCTAssertTrue(m().isBlocked("bet365.com")) }
    func testSuffixWalk() { XCTAssertTrue(m().isBlocked("www.promo.casino.com")) }
    func testToken() { XCTAssertTrue(m().isBlocked("eu.pokerstars-mirror.net")) }
    func testAllowlistWins() { XCTAssertFalse(m().isBlocked("help.casino.com")) }
    func testAllowlistSuffix() { XCTAssertFalse(m().isBlocked("a.help.casino.com")) }
    func testUnrelated() { XCTAssertFalse(m().isBlocked("example.com")) }
    func testNormalization() { XCTAssertTrue(m().isBlocked("CASINO.COM.")) }
    func testCount() { XCTAssertEqual(m().count, 2) }
}
