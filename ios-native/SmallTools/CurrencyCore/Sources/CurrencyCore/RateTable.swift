import Foundation

/// Exchange rates as units of each currency per 1 USD, plus when they were fetched.
public struct RateTable: Codable, Sendable, Equatable {
    /// Units of the currency per 1 USD. USD is always 1.
    public var perUSD: [Currency: Double]
    public var fetchedAt: Date
    /// True when built from the hardcoded fallback rates rather than a live source.
    public var isFallback: Bool

    public init(perUSD: [Currency: Double], fetchedAt: Date, isFallback: Bool) {
        self.perUSD = perUSD
        self.fetchedAt = fetchedAt
        self.isFallback = isFallback
    }

    /// The web tool's FALLBACK_RATES, stamped with `now`.
    public static func fallback(now: Date) -> RateTable {
        RateTable(perUSD: fallbackPerUSD, fetchedAt: now, isFallback: true)
    }

    /// Units of `to` per 1 `from`, pivoting through USD.
    /// Returns NaN when either currency lacks a finite, positive rate.
    public func rate(from: Currency, to: Currency) -> Double {
        guard let fromRate = usableRate(for: from), let toRate = usableRate(for: to) else {
            return .nan
        }
        return toRate / fromRate
    }

    /// Converts `amount` of `from` into `to`, using the web tool's formula:
    /// (amount / rate[from]) * rate[to]. Returns NaN when a rate is unusable.
    public func convert(_ amount: Double, from: Currency, to: Currency) -> Double {
        guard let fromRate = usableRate(for: from), let toRate = usableRate(for: to) else {
            return .nan
        }
        return amount / fromRate * toRate
    }

    /// True when every currency has a finite, positive rate and the timestamp is finite.
    /// Used to reject incomplete cache files.
    var isUsable: Bool {
        fetchedAt.timeIntervalSince1970.isFinite
            && Currency.allCases.allSatisfy { usableRate(for: $0) != nil }
    }

    private func usableRate(for currency: Currency) -> Double? {
        guard let rate = perUSD[currency], rate.isFinite, rate > 0 else { return nil }
        return rate
    }

    /// FALLBACK_RATES from the web tool, in the same units (per 1 USD).
    private static let fallbackPerUSD: [Currency: Double] = [
        .usd: 1,
        .eur: 0.92,
        .gbp: 0.79,
        .twd: 32.5,
        .jpy: 150.0,
        .cny: 7.2,
        .cad: 1.37,
    ]

    // Explicit codec: rates are a JSON object keyed by ISO code (not an array of
    // pairs, which is what a [Currency: Double] dictionary encodes to by default),
    // and the timestamp is epoch seconds so the file does not depend on the
    // encoder's date strategy.
    private enum CodingKeys: String, CodingKey {
        case perUSD, fetchedAt, isFallback
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawRates = try container.decode([String: Double].self, forKey: .perUSD)
        var table: [Currency: Double] = [:]
        for (code, rate) in rawRates {
            // Unknown codes are dropped so a cache written by a newer build still loads.
            if let currency = Currency(rawValue: code) {
                table[currency] = rate
            }
        }
        perUSD = table
        let seconds = try container.decode(Double.self, forKey: .fetchedAt)
        fetchedAt = Date(timeIntervalSince1970: seconds)
        isFallback = try container.decode(Bool.self, forKey: .isFallback)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var rawRates: [String: Double] = [:]
        for (currency, rate) in perUSD {
            rawRates[currency.code] = rate
        }
        try container.encode(rawRates, forKey: .perUSD)
        try container.encode(fetchedAt.timeIntervalSince1970, forKey: .fetchedAt)
        try container.encode(isFallback, forKey: .isFallback)
    }
}
