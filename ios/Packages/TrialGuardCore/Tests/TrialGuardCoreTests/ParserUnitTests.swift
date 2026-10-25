import XCTest
@testable import TrialGuardCore

/// Same cases as extension/tests/parser.units.test.ts.
final class ParserUnitTests: XCTestCase {
    let today = LocalDate(y: 2026, m: 10, d: 24)
    let base = (now: ISO8601DateFormatter().date(from: "2026-10-24T18:00:00Z")!, tz: "America/Toronto")

    func input(_ text: String, anchors: [Anchor] = []) -> ParseInput {
        ParseInput(text: text, anchors: anchors, now: base.now, timeZone: base.tz, locale: "en-CA", defaultCurrency: "CAD")
    }

    func testMonthAdditionClamps() {
        XCTAssertEqual(LocalDate(y: 2026, m: 1, d: 31).adding(months: 1).iso, "2026-02-28")
        XCTAssertEqual(LocalDate(y: 2026, m: 10, d: 31).adding(months: 1).iso, "2026-11-30")
        XCTAssertEqual(LocalDate(y: 2026, m: 12, d: 15).adding(months: 1).iso, "2027-01-15")
    }

    func testTodayUsesGivenTimeZone() {
        let now = ISO8601DateFormatter().date(from: "2026-10-25T02:30:00Z")!
        XCTAssertEqual(LocalDate.today(now, timeZone: "America/Toronto").iso, "2026-10-24")
        XCTAssertEqual(LocalDate.today(now, timeZone: "Asia/Dhaka").iso, "2026-10-25")
    }

    func testYearlessDateRollsForward() {
        XCTAssertEqual(DateFinder.find("ends jan 5", locale: "en-CA", today: today).first?.date.iso, "2027-01-05")
        XCTAssertEqual(DateFinder.find("ends nov 5", locale: "en-CA", today: today).first?.date.iso, "2026-11-05")
        XCTAssertEqual(DateFinder.find("ends oct 24", locale: "en-CA", today: today).first?.date.iso, "2026-10-24")
    }

    func testSlashDatesByLocale() {
        XCTAssertEqual(DateFinder.find("03/11/2026", locale: "en-US", today: today).first?.date.iso, "2026-03-11")
        XCTAssertEqual(DateFinder.find("03/11/2026", locale: "en-CA", today: today).first?.date.iso, "2026-11-03")
        XCTAssertEqual(DateFinder.find("11/23/2026", locale: "en-CA", today: today).first?.date.iso, "2026-11-23")
    }

    func testImpossibleDateRejected() {
        XCTAssertTrue(DateFinder.find("feb 30, 2026", locale: "en-CA", today: today).isEmpty)
    }

    func testFrenchFirstOfMonth() {
        XCTAssertEqual(DateFinder.find("le 1er novembre 2026", locale: "fr-CA", today: today).first?.date.iso, "2026-11-01")
    }

    func testCanonicalAmounts() {
        XCTAssertEqual(MoneyFinder.canonicalAmount("1,234.56"), "1234.56")
        XCTAssertEqual(MoneyFinder.canonicalAmount("1.234,56"), "1234.56")
        XCTAssertEqual(MoneyFinder.canonicalAmount("14,99"), "14.99")
        XCTAssertEqual(MoneyFinder.canonicalAmount("22"), "22")
        XCTAssertEqual(MoneyFinder.canonicalAmount("139.00"), "139.00")
        XCTAssertEqual(MoneyFinder.canonicalAmount("1 234,56"), "1234.56")
    }

    func testCurrencies() {
        let m = MoneyFinder.find("ca$5/mo us$6/mo $7/mo €8/mo 9,50 $/mois", defaultCurrency: "CAD")
        XCTAssertEqual(m.map(\.currency), ["CAD", "USD", "CAD", "EUR", "CAD"])
        XCTAssertEqual(MoneyFinder.find("$7/mo", defaultCurrency: "USD").first?.currency, "USD")
    }

    func testNormalize() {
        XCTAssertEqual(Normalizer.normalize("Then&nbsp;CA&#36;16.99\u{200B}/month"), "Then CA$16.99/month")
        XCTAssertEqual(Normalizer.normalize("You\u{2019}ll be charged"), "You'll be charged")
    }

    func testRejectsNonHttpsCancelAnchor() {
        let r = TrialParser.parse(input("7-day free trial, then $5/month", anchors: [Anchor(text: "Cancel", href: "javascript:alert(1)")]))
        XCTAssertNil(r.cancelURL)
    }

    func testBareTrialIsNotASignal() {
        XCTAssertFalse(TrialParser.parse(input("The trial ends on Dec 5, 2026.")).isTrial)
    }

    func testEmptyInput() {
        let r = TrialParser.parse(input(""))
        XCTAssertFalse(r.isTrial)
        XCTAssertEqual(r.confidence.overall, 0)
    }

    func testPerformanceOn20KB() {
        let text = String(repeating: "Lorem ipsum dolor sit amet. ", count: 700) + "Start your 14-day free trial. Then $8/month."
        measure { _ = TrialParser.parse(input(text)) }
        XCTAssertEqual(TrialParser.parse(input(text)).trialDays, 14)
    }
}
