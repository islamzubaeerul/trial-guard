import Foundation

// Parser contract v1.1 — see docs/contracts/parser.md. Keep in step with extension/src/parser/types.ts.

public enum Cycle: String, Codable, Sendable {
    case weekly, monthly, quarterly, yearly, unknown
}

public struct Anchor: Codable, Sendable, Equatable {
    public var text: String
    public var href: String
    public init(text: String, href: String) {
        self.text = text
        self.href = href
    }
}

public struct ParseInput: Sendable {
    public var text: String
    public var url: String?
    public var title: String?
    public var senderDomain: String?
    public var anchors: [Anchor]
    /// The moment of capture. The parser never reads the clock.
    public var now: Date
    /// IANA time zone, e.g. "America/Toronto".
    public var timeZone: String
    /// BCP-47 locale, e.g. "en-CA".
    public var locale: String
    /// ISO 4217, e.g. "CAD".
    public var defaultCurrency: String

    public init(
        text: String, url: String? = nil, title: String? = nil, senderDomain: String? = nil,
        anchors: [Anchor] = [], now: Date, timeZone: String, locale: String, defaultCurrency: String
    ) {
        self.text = text
        self.url = url
        self.title = title
        self.senderDomain = senderDomain
        self.anchors = anchors
        self.now = now
        self.timeZone = timeZone
        self.locale = locale
        self.defaultCurrency = defaultCurrency
    }
}

public struct Confidence: Codable, Sendable, Equatable {
    public var service: Double
    public var trialEnd: Double
    public var price: Double
    public var cancelURL: Double
    public var overall: Double
}

public struct ParseResult: Codable, Sendable, Equatable {
    public var isTrial: Bool
    public var serviceName: String?
    public var serviceKey: String?
    public var trialDays: Int?
    /// "YYYY-MM-DD" in the input time zone.
    public var trialEnd: String?
    public var nextChargeDate: String?
    /// Canonical decimal string, e.g. "16.99", "22", "139.00".
    public var price: String?
    public var currency: String
    public var cycle: Cycle
    public var cancelURL: String?
    public var confidence: Confidence
    public var evidence: [String: String]
}

public struct ServiceDefinition: Codable, Sendable, Equatable {
    public var key: String
    public var displayName: String
    public var names: [String]
    public var domains: [String]
    public var emailDomains: [String]
    public var cancelURL: String?
    public var supportURL: String?
    public var logo: String?
    public var defaultTrialDays: Int?
    public var billedVia: [String]
    public var lastVerified: String?
}

struct ServicesFile: Codable {
    var version: Int
    var services: [ServiceDefinition]
}

public enum ServicesDB {
    /// The services bundled with this build (Resources/services.json, synced from services-db/).
    public static let bundled: [ServiceDefinition] = {
        guard
            let url = Bundle.module.url(forResource: "services", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(ServicesFile.self, from: data)
        else {
            assertionFailure("services.json missing or invalid")
            return []
        }
        return file.services
    }()
}
