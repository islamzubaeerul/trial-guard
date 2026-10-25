import Foundation

// Thin wrapper over NSRegularExpression. Offsets are UTF-16 units, the same as JavaScript
// string indices, so the Swift and TypeScript parsers slice text identically.

struct RxMatch {
    let ns: NSString
    let result: NSTextCheckingResult

    var location: Int { result.range.location }
    var end: Int { result.range.location + result.range.length }
    var text: String { ns.substring(with: result.range) }

    func group(_ i: Int) -> String? {
        guard i < result.numberOfRanges else { return nil }
        let r = result.range(at: i)
        return r.location == NSNotFound ? nil : ns.substring(with: r)
    }
}

/// NSRegularExpression is immutable and documented thread-safe for matching.
struct Rx: @unchecked Sendable {
    let re: NSRegularExpression

    init(_ pattern: String, caseInsensitive: Bool = false) {
        do {
            re = try NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
        } catch {
            preconditionFailure("Invalid regex \(pattern): \(error)")
        }
    }

    func first(in s: String) -> RxMatch? {
        let ns = s as NSString
        return re.firstMatch(in: s, options: [], range: NSRange(location: 0, length: ns.length))
            .map { RxMatch(ns: ns, result: $0) }
    }

    func all(in s: String) -> [RxMatch] {
        let ns = s as NSString
        return re.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
            .map { RxMatch(ns: ns, result: $0) }
    }

    func test(_ s: String) -> Bool { first(in: s) != nil }

    /// Replace every match with the closure's output.
    func replace(in s: String, _ transform: (RxMatch) -> String) -> String {
        let matches = all(in: s)
        guard !matches.isEmpty else { return s }
        let out = NSMutableString(string: s)
        for m in matches.reversed() {
            out.replaceCharacters(in: m.result.range, with: transform(m))
        }
        return out as String
    }

    /// Replace every match with a literal string.
    func replace(in s: String, with literal: String) -> String {
        replace(in: s) { _ in literal }
    }

    /// Split like JavaScript's `String.prototype.split(regex)` (no capture groups).
    func split(_ s: String) -> [String] {
        let ns = s as NSString
        var parts: [String] = []
        var start = 0
        for m in all(in: s) {
            if m.end == m.location { continue }
            parts.append(ns.substring(with: NSRange(location: start, length: m.location - start)))
            start = m.end
        }
        parts.append(ns.substring(from: start))
        return parts
    }
}

extension String {
    var utf16Length: Int { (self as NSString).length }

    /// UTF-16 slice clamped to bounds, like JavaScript's `slice(from, to)`.
    func slice(_ from: Int, _ to: Int? = nil) -> String {
        let ns = self as NSString
        let a = max(0, min(from, ns.length))
        let b = max(a, min(to ?? ns.length, ns.length))
        return ns.substring(with: NSRange(location: a, length: b - a))
    }
}
