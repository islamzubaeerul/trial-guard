import Foundation

struct MoneyMatch {
    var index: Int
    var end: Int
    var amount: String  // canonical decimal string
    var currency: String
    var cycle: Cycle
    var cycleEnd: Int
}

struct PriceChoice {
    var money: MoneyMatch
    var confidence: Double
}

/// Mirrors extension/src/parser/money.ts.
enum MoneyFinder {
    static let num = "(\\d{1,3}(?:[.,\\s]\\d{3})+(?:[.,]\\d{1,2})?|\\d+(?:[.,]\\d{1,2})?)"
    static let rePre = Rx("(?<![a-z])(ca\\$|c\\$|us\\$|a\\$|cad|usd|eur|gbp|€|£|¥|\\$)\\s?\(num)(?:\\s?(cad|usd|eur)(?![a-z]))?")
    static let rePost = Rx("(?<![\\d.,$])\(num)\\s?(\\$\\s?ca(?![a-z])|\\$|€|cad(?![a-z])|usd(?![a-z])|eur(?![a-z]))")
    static let reCycle = Rx(
        "^[ ,]{0,2}(?:/|per|a|an|every|each|par|billed)?\\s*(?:billed\\s+)?(monthly|month|mth|mo|annually|annual|annum|yearly|year|yr|quarterly|quarter|weekly|week|wk|mois|année|an|semaine)(?![a-zà-ÿ])"
    )
    static let cycleOf: [String: Cycle] = [
        "monthly": .monthly, "month": .monthly, "mth": .monthly, "mo": .monthly, "mois": .monthly,
        "annually": .yearly, "annual": .yearly, "annum": .yearly, "yearly": .yearly, "year": .yearly,
        "yr": .yearly, "année": .yearly, "an": .yearly,
        "quarterly": .quarterly, "quarter": .quarterly,
        "weekly": .weekly, "week": .weekly, "wk": .weekly, "semaine": .weekly,
    ]
    static let decimalTail = Rx("[.,](\\d{1,2})$")
    static let separators = Rx("[.,\\s]")
    static let whitespace = Rx("\\s")

    static func canonicalAmount(_ raw: String) -> String {
        let s = whitespace.replace(in: raw, with: " ").trimmingCharacters(in: .whitespaces)
        if let dec = decimalTail.first(in: s) {
            let intPart = separators.replace(in: s.slice(0, dec.location), with: "")
            return "\(intPart).\(dec.group(1)!)"
        }
        return separators.replace(in: s, with: "")
    }

    static func currency(_ token: String, _ defaultCurrency: String) -> String {
        let t = whitespace.replace(in: token, with: "").lowercased()
        switch t {
        case "ca$", "c$", "cad", "$ca": return "CAD"
        case "us$", "usd": return "USD"
        case "a$": return "AUD"
        case "€", "eur": return "EUR"
        case "£", "gbp": return "GBP"
        case "¥": return "JPY"
        default: return defaultCurrency
        }
    }

    static func cycleAt(_ lower: String, _ end: Int) -> (Cycle, Int) {
        guard let m = reCycle.first(in: lower.slice(end, end + 24)) else { return (.unknown, end) }
        return (cycleOf[m.group(1)!] ?? .unknown, end + m.end)
    }

    static func find(_ lower: String, defaultCurrency: String) -> [MoneyMatch] {
        var out: [MoneyMatch] = []
        for m in rePre.all(in: lower) {
            let cur = m.group(3).map { currency($0, defaultCurrency) } ?? currency(m.group(1)!, defaultCurrency)
            let (cycle, cycleEnd) = cycleAt(lower, m.end)
            out.append(MoneyMatch(index: m.location, end: m.end, amount: canonicalAmount(m.group(2)!),
                                  currency: cur, cycle: cycle, cycleEnd: cycleEnd))
        }
        for m in rePost.all(in: lower) {
            if out.contains(where: { m.location < $0.end && m.end > $0.index }) { continue }
            let (cycle, cycleEnd) = cycleAt(lower, m.end)
            out.append(MoneyMatch(index: m.location, end: m.end, amount: canonicalAmount(m.group(1)!),
                                  currency: currency(m.group(2)!, defaultCurrency), cycle: cycle, cycleEnd: cycleEnd))
        }
        return out.sorted { $0.index < $1.index }
    }

    static let rejectBefore = Rx("(?<![a-z])(save|was|off|discount|économisez|today)(?![a-z])[^.\\n]*$")
    static let dueToday = Rx("due today")
    static let offAfter = Rx("^\\s{0,2}off(?![a-z])")
    static let cueBefore = Rx("(?<![a-z])(then|after|renews? at|renew|billed|fee of|puis|facturée?|pay)(?![a-z])")

    static func choose(_ lower: String, _ money: [MoneyMatch], anchor: Int) -> PriceChoice? {
        let usable = money.filter { m in
            if (Double(m.amount) ?? 0) == 0 { return false }
            let before = lower.slice(max(0, m.index - 20), m.index)
            if rejectBefore.test(before.slice(max(0, before.utf16Length - 15))) || dueToday.test(before) { return false }
            if offAfter.test(lower.slice(m.end, m.end + 6)) { return false }
            return true
        }
        let cycled = usable.filter { $0.cycle != .unknown }
        let cued = cycled.filter { cueBefore.test(lower.slice(max(0, $0.index - 30), $0.index)) }
        func nearest(_ list: [MoneyMatch]) -> MoneyMatch {
            list.dropFirst().reduce(list[0]) { best, m in
                abs(m.index - anchor) < abs(best.index - anchor) ? m : best
            }
        }
        if !cued.isEmpty { return PriceChoice(money: nearest(cued), confidence: 0.95) }
        if !cycled.isEmpty { return PriceChoice(money: nearest(cycled), confidence: 0.7) }
        let close = usable.filter { abs($0.index - anchor) <= 120 }
        if !close.isEmpty { return PriceChoice(money: nearest(close), confidence: 0.4) }
        return nil
    }
}
