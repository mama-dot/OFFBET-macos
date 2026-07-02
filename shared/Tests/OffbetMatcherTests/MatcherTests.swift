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

    // --- edge cases ---
    func testEmptyHostIsSafe() { XCTAssertFalse(m().isBlocked("")) }
    func testExactAllowlistedHostNotBlocked() {
        // Regression: an exact allowlist entry must win even though its parent
        // (casino.com) is blocked — the suffix walk once ignored the host itself.
        XCTAssertFalse(m().isBlocked("help.casino.com"))
    }
    func testTokenIsCaseInsensitive() { XCTAssertTrue(m().isBlocked("EU.PokerStars.NET")) }
    func testSiblingOfAllowlistedStillBlocked() {
        // help.casino.com is allowlisted; another subdomain of the blocked parent
        // must still be blocked.
        XCTAssertTrue(m().isBlocked("promo.casino.com"))
    }
    func testReplaceSwapsTheSet() {
        let mm = m()
        mm.replace(domains: ["unibet.com"], tokens: [], allowlist: [])
        XCTAssertTrue(mm.isBlocked("unibet.com"))
        XCTAssertFalse(mm.isBlocked("bet365.com"))   // old entry gone
        XCTAssertEqual(mm.count, 1)
    }
}
