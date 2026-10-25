import Foundation

// SAME list, SAME order as extension/src/parser/patterns.ts. Change both together, with a fixture.

enum LengthUnit { case day, week, month, year }

struct LengthPattern {
    var rx: Rx
    var fixedNumber: Int?
}

enum Patterns {
    static let numWords =
        "one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|une|un|deux|trois|quatre|cinq|six|sept|huit|neuf|dix|onze|douze"
    static let num = "(\\d{1,3}|\(numWords))"
    static let unitEN = "(day|week|month|year)s?"
    static let unitFR = "(jours?|semaines?|mois|ans?)"

    static let length: [LengthPattern] = [
        LengthPattern(rx: Rx("(?<![a-z\\d])\(num)[\\s-]+\(unitEN)[\\s-]+(?:free[\\s-]+)?trial")),
        LengthPattern(rx: Rx("(?<![a-z])free\\s+(?:trial\\s+)?for\\s+\(num)\\s+\(unitEN)(?![a-z])")),
        LengthPattern(rx: Rx("(?<![a-z])(?:free\\s+)?trial\\s+(?:of|for)\\s+\(num)\\s+\(unitEN)(?![a-z])")),
        LengthPattern(rx: Rx("(?<![a-z\\d])\(num)\\s+\(unitEN)\\s+free(?![a-z])")),
        LengthPattern(rx: Rx("(?<![a-z])(?:first|1st)\\s+(week|month|year)\\s+(?:is\\s+)?free(?![a-z])"), fixedNumber: 1),
        LengthPattern(rx: Rx("essai\\s+gratuit\\s+(?:de|d'une\\s+durée\\s+de)\\s+\(num)\\s+\(unitFR)(?![a-zà-ÿ])")),
        LengthPattern(rx: Rx("(?<![a-z\\d])\(num)\\s+\(unitFR)\\s+(?:d'essai\\s+gratuit|d'essai|gratuits?)(?![a-zà-ÿ])")),
        LengthPattern(rx: Rx("période\\s+d'essai\\s+(?:gratuite\\s+)?de\\s+\(num)\\s+\(unitFR)(?![a-zà-ÿ])")),
    ]

    static let trialPhrase = Rx(
        "free trial|trial period|try (?:it )?free|first (?:month|week|year) (?:is )?free|essai gratuit|période d'essai|\\d+ (?:days?|weeks?|months?) free"
    )

    static let numberOf: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4, "cinq": 5, "sept": 7,
        "huit": 8, "neuf": 9, "dix": 10, "onze": 11, "douze": 12,
    ]

    static func number(_ token: String) -> Int? {
        if let n = Int(token) { return n }
        return numberOf[token]
    }

    static func unit(_ token: String) -> LengthUnit {
        if token.hasPrefix("day") || token.hasPrefix("jour") { return .day }
        if token.hasPrefix("week") || token.hasPrefix("semaine") { return .week }
        if token.hasPrefix("month") || token == "mois" { return .month }
        return .year
    }

    static let endCue = Rx(
        "(trial(?: period)? (?:ends|expires|will end|is over)|free until|cancel (?:any ?time )?before|se termine(?: le)?|prendra fin(?: le)?)(?:(?!\\.\\s)[^!?\\n]){0,45}$"
    )
    static let chargeCue = Rx(
        "(be charged|be billed|charged|billed|first (?:payment|charge|bill)|billing date|renews|renew|renewal date|billing starts|facturée?|prélevée?)(?:(?!\\.\\s)[^!?\\n]){0,45}$"
    )
    static let afterCue = Rx("^[\\s,]*(?:you'll|you will) be (?:charged|billed)")

    static let cancelAnchor = Rx(
        "cancel|manage (?:your )?(?:subscription|plan|membership)|billing|account settings|gérer (?:mon|votre) abonnement",
        caseInsensitive: true
    )
}
