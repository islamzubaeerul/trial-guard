import Foundation

struct ServiceMatch {
    var name: String
    var key: String?
    var def: ServiceDefinition?
    var confidence: Double
    var evidence: String
}

/// Mirrors extension/src/parser/service.ts.
enum ServiceMatcher {
    static let wordChar = Rx("^[A-Za-z0-9À-ÿ]$")

    static func isWordChar(_ ns: NSString, _ i: Int) -> Bool {
        guard i >= 0, i < ns.length else { return false }
        return wordChar.test(ns.substring(with: NSRange(location: i, length: 1)))
    }

    /// Case-sensitive, word-bounded search that also works for aliases ending in "+". Returns -1 if absent.
    static func findAlias(_ hay: String, _ alias: String) -> Int {
        let ns = hay as NSString
        let a = alias as NSString
        guard a.length > 0 else { return -1 }
        let lastIsWord = isWordChar(a, a.length - 1)
        var from = 0
        while from <= ns.length {
            let r = ns.range(of: alias, options: [.literal], range: NSRange(location: from, length: ns.length - from))
            if r.location == NSNotFound { return -1 }
            let beforeOK = !isWordChar(ns, r.location - 1)
            let afterOK = !lastIsWord || !isWordChar(ns, r.location + r.length)
            if beforeOK && afterOK { return r.location }
            from = r.location + 1
        }
        return -1
    }

    static func host(_ url: String?) -> String? {
        guard let url, let h = URL(string: url)?.host?.lowercased() else { return nil }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    static func domainMatches(_ host: String, _ domain: String) -> Bool {
        host == domain || host.hasSuffix(".\(domain)")
    }

    static func aliasScore(_ def: ServiceDefinition, _ hay: String) -> Int {
        var best = 0
        for n in def.names where n.utf16Length > best && findAlias(hay, n) >= 0 { best = n.utf16Length }
        return best
    }

    /// Among several candidates, prefer an alias in the title, then the longest alias in the text.
    static func pick(_ cands: [ServiceDefinition], title: String, text: String) -> ServiceDefinition {
        if cands.count == 1 { return cands[0] }
        var best = cands[0]
        var bestScore = -1
        for c in cands {
            let t = aliasScore(c, title)
            let score = t > 0 ? 1000 + t : aliasScore(c, text)
            if score > bestScore {
                best = c
                bestScore = score
            }
        }
        return best
    }

    static let boilerplate = Rx(
        "(welcome to|your receipt from|confirm your|order confirmation|checkout|sign up|subscribe to|subscribe|start your free trial)",
        caseInsensitive: true
    )
    static let titleSplit = Rx("\\s+[|\\-—·]\\s+|^\\s*[|\\-—·:]\\s*|\\s*[|\\-—·:]\\s*$")

    static func identify(
        _ services: [ServiceDefinition], text: String, title: String?, url: String?, senderDomain: String?
    ) -> ServiceMatch? {
        let t = title ?? ""
        if let h = host(url) {
            let c = services.filter { $0.domains.contains { domainMatches(h, $0) } }
            if !c.isEmpty {
                let def = pick(c, title: t, text: text)
                return ServiceMatch(name: def.displayName, key: def.key, def: def, confidence: 0.95, evidence: h)
            }
        }
        if let sender = senderDomain?.lowercased() {
            let c = services.filter { ($0.emailDomains + $0.domains).contains { domainMatches(sender, $0) } }
            if !c.isEmpty {
                let def = pick(c, title: t, text: text)
                return ServiceMatch(name: def.displayName, key: def.key, def: def, confidence: 0.95, evidence: sender)
            }
        }
        let head = text.slice(0, 300)
        let named = services.filter { aliasScore($0, t) > 0 || aliasScore($0, head) > 0 }
        if !named.isEmpty {
            let def = pick(named, title: t, text: head)
            return ServiceMatch(name: def.displayName, key: def.key, def: def, confidence: 0.7, evidence: def.displayName)
        }
        if !t.isEmpty {
            let parts = titleSplit.split(boilerplate.replace(in: t, with: ""))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.utf16Length >= 2 && $0.utf16Length <= 40 }
            // Stable sort by length, longest first (JavaScript's sort is stable).
            let best = parts.enumerated()
                .sorted { $0.element.utf16Length != $1.element.utf16Length
                    ? $0.element.utf16Length > $1.element.utf16Length : $0.offset < $1.offset }
                .first?.element
            if let best { return ServiceMatch(name: best, key: nil, def: nil, confidence: 0.4, evidence: t) }
        }
        return nil
    }
}
