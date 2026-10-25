import Foundation

/// A calendar date with no time or zone. A trial ends on a *day*.
public struct LocalDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public var y: Int
    public var m: Int  // 1-12
    public var d: Int  // 1-31

    public init(y: Int, m: Int, d: Int) {
        self.y = y
        self.m = m
        self.d = d
    }

    public var iso: String { String(format: "%04d-%02d-%02d", y, m, d) }
    public var description: String { iso }

    public init?(iso: String) {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        self.init(y: p[0], m: p[1], d: p[2])
        guard isValid else { return nil }
    }

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func daysInMonth(_ y: Int, _ m: Int) -> Int {
        let date = utc.date(from: DateComponents(year: y, month: m, day: 1))!
        return utc.range(of: .day, in: .month, for: date)!.count
    }

    public var isValid: Bool { m >= 1 && m <= 12 && d >= 1 && d <= LocalDate.daysInMonth(y, m) }

    private var epochDays: Int {
        let date = LocalDate.utc.date(from: DateComponents(year: y, month: m, day: d))!
        return Int((date.timeIntervalSince1970 / 86_400).rounded())
    }

    public func adding(days n: Int) -> LocalDate {
        let t = Date(timeIntervalSince1970: Double(epochDays + n) * 86_400)
        let c = LocalDate.utc.dateComponents([.year, .month, .day], from: t)
        return LocalDate(y: c.year!, m: c.month!, d: c.day!)
    }

    /// Calendar month addition; the day is clamped (Oct 31 + 1 month = Nov 30).
    public func adding(months n: Int) -> LocalDate {
        let total = y * 12 + (m - 1) + n
        let ny = Int((Double(total) / 12).rounded(.down))
        let nm = total - ny * 12 + 1
        return LocalDate(y: ny, m: nm, d: min(d, LocalDate.daysInMonth(ny, nm)))
    }

    public static func daysBetween(_ a: LocalDate, _ b: LocalDate) -> Int { b.epochDays - a.epochDays }

    public static func < (a: LocalDate, b: LocalDate) -> Bool { a.epochDays < b.epochDays }

    /// Today's date in the given IANA time zone.
    public static func today(_ now: Date, timeZone: String) -> LocalDate {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZone) ?? TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day], from: now)
        return LocalDate(y: c.year!, m: c.month!, d: c.day!)
    }
}

struct DateMatch {
    var index: Int
    var end: Int
    var date: LocalDate
}

enum DateFinder {
    static let months: [String: Int] = [
        "january": 1, "jan": 1, "janvier": 1, "janv": 1,
        "february": 2, "feb": 2, "février": 2, "fevrier": 2, "févr": 2, "fevr": 2,
        "march": 3, "mar": 3, "mars": 3,
        "april": 4, "apr": 4, "avril": 4, "avr": 4,
        "may": 5, "mai": 5,
        "june": 6, "jun": 6, "juin": 6,
        "july": 7, "jul": 7, "juillet": 7, "juil": 7,
        "august": 8, "aug": 8, "août": 8, "aout": 8,
        "september": 9, "sept": 9, "sep": 9, "septembre": 9,
        "october": 10, "oct": 10, "octobre": 10,
        "november": 11, "nov": 11, "novembre": 11,
        "december": 12, "dec": 12, "décembre": 12, "decembre": 12, "déc": 12,
    ]

    static let monthAlt: String = months.keys
        .sorted { $0.utf16Length != $1.utf16Length ? $0.utf16Length > $1.utf16Length : $0 < $1 }
        .joined(separator: "|")

    static let reMDY = Rx("(?<![a-zà-ÿ])(\(monthAlt))\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?(?!\\d)")
    static let reDMY = Rx("(?<!\\d)(\\d{1,2})(?:er|st|nd|rd|th)?\\s+(\(monthAlt))(?![a-zà-ÿ])\\.?(?:,?\\s+(\\d{4}))?(?!\\d)")
    static let reISO = Rx("(?<!\\d)(\\d{4})-(\\d{2})-(\\d{2})(?!\\d)")
    static let reSlash = Rx("(?<!\\d)(\\d{1,2})/(\\d{1,2})/(\\d{4})(?!\\d)")

    /// Resolve a day/month without a year to its next occurrence on or after today.
    static func withYear(_ m: Int, _ d: Int, _ y: String?, _ today: LocalDate) -> LocalDate {
        if let y, let year = Int(y) { return LocalDate(y: year, m: m, d: d) }
        let candidate = LocalDate(y: today.y, m: m, d: d)
        guard candidate.isValid else { return candidate }
        return candidate >= today ? candidate : LocalDate(y: today.y + 1, m: m, d: d)
    }

    /// Every date in a lowercased, normalized text. Overlaps keep the longer match.
    static func find(_ lower: String, locale: String, today: LocalDate) -> [DateMatch] {
        var found: [DateMatch] = []
        func push(_ m: RxMatch, _ date: LocalDate) {
            if date.isValid { found.append(DateMatch(index: m.location, end: m.end, date: date)) }
        }
        for m in reMDY.all(in: lower) {
            guard let mo = months[m.group(1)!], let d = Int(m.group(2)!) else { continue }
            push(m, withYear(mo, d, m.group(3), today))
        }
        for m in reDMY.all(in: lower) {
            guard let mo = months[m.group(2)!], let d = Int(m.group(1)!) else { continue }
            push(m, withYear(mo, d, m.group(3), today))
        }
        for m in reISO.all(in: lower) {
            push(m, LocalDate(y: Int(m.group(1)!)!, m: Int(m.group(2)!)!, d: Int(m.group(3)!)!))
        }
        for m in reSlash.all(in: lower) {
            let a = Int(m.group(1)!)!
            let b = Int(m.group(2)!)!
            let (month, day): (Int, Int)
            if a > 12 { (day, month) = (a, b) }
            else if b > 12 { (month, day) = (a, b) }
            else if locale.lowercased() == "en-us" { (month, day) = (a, b) }
            else { (day, month) = (a, b) }
            push(m, LocalDate(y: Int(m.group(3)!)!, m: month, d: day))
        }
        found.sort { $0.index != $1.index ? $0.index < $1.index : $0.end > $1.end }
        var out: [DateMatch] = []
        for f in found {
            if let last = out.last, f.index < last.end { continue }
            out.append(f)
        }
        return out
    }
}
