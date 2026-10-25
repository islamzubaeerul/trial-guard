import Foundation

/// Turns trial signup text into a pre-filled capture. Contract: docs/contracts/parser.md.
/// Mirrors extension/src/parser/index.ts; scripts/parser-parity.sh checks they agree.
public enum TrialParser {
    private struct Length {
        var n: Int
        var unit: LengthUnit
        var index: Int
        var raw: String
    }

    private static func round2(_ x: Double) -> Double { (x * 100).rounded() / 100 }

    private static func findLength(_ lower: String) -> Length? {
        var best: Length?
        for p in Patterns.length {
            guard let m = p.rx.first(in: lower) else { continue }
            let n = p.fixedNumber ?? Patterns.number(m.group(1) ?? "")
            let unit = Patterns.unit((p.fixedNumber != nil ? m.group(1) : m.group(2)) ?? "")
            guard let n, n > 0, n <= 366 else { continue }
            if best == nil || m.location < best!.index {
                best = Length(n: n, unit: unit, index: m.location, raw: m.text)
            }
        }
        return best
    }

    private static func add(_ len: Length, to today: LocalDate) -> LocalDate {
        switch len.unit {
        case .day: today.adding(days: len.n)
        case .week: today.adding(days: 7 * len.n)
        case .month: today.adding(months: len.n)
        case .year: today.adding(months: 12 * len.n)
        }
    }

    public static func parse(_ input: ParseInput, services: [ServiceDefinition] = ServicesDB.bundled) -> ParseResult {
        let text = Normalizer.normalize(input.text)
        let lower = text.lowercased()
        let title = input.title.map(Normalizer.normalize)
        let today = LocalDate.today(input.now, timeZone: input.timeZone)
        var evidence: [String: String] = [:]

        // Service
        let service = ServiceMatcher.identify(
            services, text: text, title: title, url: input.url, senderDomain: input.senderDomain)
        if let service { evidence["service"] = service.evidence }

        // Trial signal and length
        let length = findLength(lower)
        let phrase = Patterns.trialPhrase.first(in: lower)
        let isTrial = length != nil || phrase != nil
        let trialPos = length?.index ?? phrase?.location ?? 0
        if let length { evidence["trialLength"] = text.slice(length.index, length.index + length.raw.utf16Length) }

        // Dates
        var trialEnd: LocalDate?
        var trialEndConf = 0.0
        var nextCharge: LocalDate?
        for d in DateFinder.find(lower, locale: input.locale, today: today) {
            let before = lower.slice(max(0, d.index - 50), d.index)
            let after = lower.slice(d.end, d.end + 40)
            let charge = Patterns.chargeCue.test(before) || Patterns.afterCue.test(after)
            let end = Patterns.endCue.test(before)
            if isTrial, trialEnd == nil, charge || end {
                trialEnd = d.date
                trialEndConf = 0.95
                evidence["trialEnd"] = text.slice(d.index, d.end)
            }
            if !isTrial, nextCharge == nil, charge {
                nextCharge = d.date
                evidence["nextChargeDate"] = text.slice(d.index, d.end)
            }
        }
        if isTrial, trialEnd == nil, let length {
            trialEnd = add(length, to: today)
            trialEndConf = 0.7
        }
        var trialDays: Int?
        if isTrial, let length {
            trialDays = LocalDate.daysBetween(today, add(length, to: today))
        } else if isTrial, let trialEnd, trialEnd > today {
            trialDays = LocalDate.daysBetween(today, trialEnd)
        }

        // Price
        let price = MoneyFinder.choose(lower, MoneyFinder.find(lower, defaultCurrency: input.defaultCurrency), anchor: trialPos)
        if let price { evidence["price"] = text.slice(price.money.index, price.money.cycleEnd) }

        // Cancel URL
        var cancelURL: String?
        var cancelConf = 0.0
        if let anchor = input.anchors.first(where: {
            $0.href.lowercased().hasPrefix("https://") && Patterns.cancelAnchor.test($0.text)
        }) {
            cancelURL = anchor.href
            cancelConf = 0.95
            evidence["cancelURL"] = anchor.text
        } else if let url = service?.def?.cancelURL {
            cancelURL = url
            cancelConf = 0.7
        }

        // Score
        let serviceConf = service?.confidence ?? 0
        let priceConf = price?.confidence ?? 0
        var overall = 0.3 * serviceConf + 0.35 * trialEndConf + 0.2 * priceConf + 0.15 * cancelConf
        if !isTrial { overall /= 2 }

        return ParseResult(
            isTrial: isTrial,
            serviceName: service?.name,
            serviceKey: service?.key,
            trialDays: trialDays,
            trialEnd: isTrial ? trialEnd?.iso : nil,
            nextChargeDate: nextCharge?.iso,
            price: price?.money.amount,
            currency: price?.money.currency ?? input.defaultCurrency,
            cycle: price?.money.cycle ?? .unknown,
            cancelURL: cancelURL,
            confidence: Confidence(
                service: round2(serviceConf), trialEnd: round2(trialEndConf), price: round2(priceConf),
                cancelURL: round2(cancelConf), overall: round2(overall)),
            evidence: evidence
        )
    }
}
