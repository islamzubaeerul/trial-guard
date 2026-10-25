import XCTest
import TrialGuardCore
import TrialGuardFixtures

/// Runs every case in parser-fixtures/ against the Swift parser (contract v1.1).
final class ParserFixtureTests: XCTestCase {
    func testAllFixtures() throws {
        let fixtures = try Fixtures.load()
        XCTAssertGreaterThanOrEqual(fixtures.count, 40, "fixture corpus went missing")
        var failures: [String] = []
        for fx in fixtures {
            for c in Fixtures.check(TrialParser.parse(fx.input), fx.expected) where !c.ok {
                failures.append("\(fx.name): \(c.field) expected \(c.expected) got \(c.actual)")
            }
        }
        XCTAssertTrue(failures.isEmpty, "\n" + failures.joined(separator: "\n"))
    }

    func testAccuracyTargets() throws {
        let fixtures = try Fixtures.load()
        var tally: [String: (ok: Int, n: Int)] = [:]
        for fx in fixtures {
            for c in Fixtures.check(TrialParser.parse(fx.input), fx.expected) {
                let t = tally[c.field] ?? (0, 0)
                tally[c.field] = (t.ok + (c.ok ? 1 : 0), t.n + 1)
            }
        }
        let targets = ["serviceKey": 0.95, "trialEnd": 0.90, "price": 0.85]
        for (field, target) in targets {
            guard let t = tally[field], t.n > 0 else { continue }
            XCTAssertGreaterThanOrEqual(Double(t.ok) / Double(t.n), target, "\(field) below target")
        }
    }
}
