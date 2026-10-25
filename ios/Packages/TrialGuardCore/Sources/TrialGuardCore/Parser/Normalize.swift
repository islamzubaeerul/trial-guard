import Foundation

enum Normalizer {
    static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "euro": "€", "pound": "£",
        "yen": "¥", "rsquo": "'", "lsquo": "'", "rdquo": "\"", "ldquo": "\"", "ndash": "–", "mdash": "—",
        "hellip": "…", "eacute": "é", "egrave": "è", "agrave": "à", "ccedil": "ç", "ocirc": "ô",
    ]

    static let hexEntity = Rx("&#x([0-9a-f]+);", caseInsensitive: true)
    static let decEntity = Rx("&#(\\d+);")
    static let namedEntity = Rx("&([a-z]+);", caseInsensitive: true)
    static let zeroWidth = Rx("[\\u200B-\\u200D\\uFEFF]")
    static let spaces = Rx("[\\u00A0\\u202F\\u2009]")
    static let singleQuotes = Rx("[\\u2018\\u2019\\u02BC]")
    static let doubleQuotes = Rx("[\\u201C\\u201D]")
    static let crlf = Rx("\\r\\n?")
    static let blanks = Rx("[ \\t\\f\\u000B]+")
    static let newlines = Rx(" ?\\n[\\n ]*")

    private static func scalar(_ value: UInt32?) -> String {
        guard let value, let s = Unicode.Scalar(value) else { return "" }
        return String(Character(s))
    }

    /// Contract step 1. Mirrors extension/src/parser/normalize.ts exactly.
    static func normalize(_ input: String) -> String {
        var s = input
        s = hexEntity.replace(in: s) { scalar(UInt32($0.group(1)!, radix: 16)) }
        s = decEntity.replace(in: s) { scalar(UInt32($0.group(1)!)) }
        s = namedEntity.replace(in: s) { named[$0.group(1)!.lowercased()] ?? $0.text }
        s = zeroWidth.replace(in: s, with: "")
        s = spaces.replace(in: s, with: " ")
        s = singleQuotes.replace(in: s, with: "'")
        s = doubleQuotes.replace(in: s, with: "\"")
        s = crlf.replace(in: s, with: "\n")
        s = blanks.replace(in: s, with: " ")
        s = newlines.replace(in: s, with: "\n")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
