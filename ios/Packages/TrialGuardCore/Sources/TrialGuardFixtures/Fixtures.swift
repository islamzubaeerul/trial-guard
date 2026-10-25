import Foundation
import TrialGuardCore

/// Loads parser-fixtures/ (format: docs/contracts/parser.md). Mirrors extension/tests/fixtures.ts.
public struct Fixture: Sendable {
    public var name: String
    public var input: ParseInput
    public var expected: [String: ExpectedValue]
}

public enum ExpectedValue: Sendable, Equatable, Decodable {
    case absent
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    // JSONDecoder is strict about types, so true never decodes as 1 and 1 never as true.
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .absent }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int.self) { self = .int(i) }
        else if let d = try? c.decode(Double.self) { self = .double(d) }
        else { self = .string(try c.decode(String.self)) }
    }
}

public struct FieldCheck: Sendable {
    public var field: String
    public var expected: String
    public var actual: String
    public var ok: Bool
}

public enum Fixtures {
    /// `<repo>/parser-fixtures`, found relative to this source file.
    public static var defaultDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // TrialGuardFixtures
            .deletingLastPathComponent()  // Sources
            .deletingLastPathComponent()  // TrialGuardCore
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // ios
            .deletingLastPathComponent()  // repo
            .appendingPathComponent("parser-fixtures")
    }

    public static func load(from dir: URL = defaultDirectory) throws -> [Fixture] {
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".txt") }
            .sorted()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return try files.map { file in
            let name = String(file.dropLast(4))
            let raw = try String(contentsOf: dir.appendingPathComponent(file), encoding: .utf8)
            let lines = raw.components(separatedBy: "\n")
            var meta: [String: String] = [:]
            var anchors: [Anchor] = []
            var i = 0
            while i < lines.count, lines[i].hasPrefix("#! ") {
                let body = String(lines[i].dropFirst(3))
                if let eq = body.firstIndex(of: "="),
                   ["url", "title", "sender", "anchor"].contains(String(body[..<eq])) {
                    let key = String(body[..<eq])
                    let value = String(body[body.index(after: eq)...])
                    if key == "anchor" {
                        let parts = value.split(separator: "|", maxSplits: 1).map(String.init)
                        anchors.append(Anchor(text: parts[0], href: parts.count > 1 ? parts[1] : ""))
                    } else {
                        meta[key] = value
                    }
                } else {
                    for kv in body.split(separator: " ") {
                        guard let eq = kv.firstIndex(of: "=") else { continue }
                        meta[String(kv[..<eq])] = String(kv[kv.index(after: eq)...])
                    }
                }
                i += 1
            }
            let input = ParseInput(
                text: lines[i...].joined(separator: "\n"),
                url: meta["url"], title: meta["title"], senderDomain: meta["sender"], anchors: anchors,
                now: iso.date(from: meta["now"] ?? "") ?? Date(timeIntervalSince1970: 0),
                timeZone: meta["tz"] ?? "America/Toronto",
                locale: meta["locale"] ?? "en-CA",
                defaultCurrency: meta["currency"] ?? "CAD")
            let data = try Data(contentsOf: dir.appendingPathComponent("\(name).expected.json"))
            let decoded = try JSONDecoder().decode([String: ExpectedValue].self, from: data)
            let expected = decoded.filter { !$0.key.hasPrefix("_") }
            return Fixture(name: name, input: input, expected: expected)
        }
    }

    public static let fields = [
        "isTrial", "serviceName", "serviceKey", "trialDays", "trialEnd", "nextChargeDate",
        "price", "currency", "cycle", "cancelURL",
    ]

    static func actual(_ r: ParseResult, _ field: String) -> ExpectedValue {
        func s(_ x: String?) -> ExpectedValue { x.map { .string($0) } ?? .absent }
        switch field {
        case "isTrial": return .bool(r.isTrial)
        case "serviceName": return s(r.serviceName)
        case "serviceKey": return s(r.serviceKey)
        case "trialDays": return r.trialDays.map { .int($0) } ?? .absent
        case "trialEnd": return s(r.trialEnd)
        case "nextChargeDate": return s(r.nextChargeDate)
        case "price": return s(r.price)
        case "currency": return .string(r.currency)
        case "cycle": return .string(r.cycle.rawValue)
        case "cancelURL": return s(r.cancelURL)
        default: return .absent
        }
    }

    static func threshold(_ v: ExpectedValue?) -> Double? {
        switch v {
        case .double(let d)?: return d
        case .int(let i)?: return Double(i)
        default: return nil
        }
    }

    public static func check(_ r: ParseResult, _ expected: [String: ExpectedValue]) -> [FieldCheck] {
        var out: [FieldCheck] = []
        for f in fields {
            guard let exp = expected[f] else { continue }
            let act = actual(r, f)
            out.append(FieldCheck(field: f, expected: "\(exp)", actual: "\(act)", ok: exp == act))
        }
        if let t = threshold(expected["overallBelow"]) {
            out.append(FieldCheck(field: "overallBelow", expected: "< \(t)", actual: "\(r.confidence.overall)",
                                  ok: r.confidence.overall < t))
        }
        if let t = threshold(expected["overallAtLeast"]) {
            out.append(FieldCheck(field: "overallAtLeast", expected: ">= \(t)", actual: "\(r.confidence.overall)",
                                  ok: r.confidence.overall >= t))
        }
        return out
    }
}
