import Foundation

/// Chooses the rates the converter uses, in order: the first live source that returns a
/// complete payload (which is then cached), the cached table from an earlier success,
/// and finally the hardcoded fallback.
public enum RateProvider {
    /// Same endpoints and order as the web tool.
    private static let sourceURLs = [
        "https://open.er-api.com/v6/latest/USD",
        "https://api.exchangerate-api.com/v4/latest/USD",
    ]

    /// Never throws. Every failure falls through to the next step.
    public static func loadRates(
        fetcher: HTTPFetching,
        cache: RateCaching,
        now: Date = Date()
    ) async -> RateTable {
        for source in sourceURLs {
            guard let url = URL(string: source),
                  let data = try? await fetcher.data(from: url),
                  let perUSD = parseRates(data) else {
                continue
            }
            let table = RateTable(perUSD: perUSD, fetchedAt: now, isFallback: false)
            cache.save(table)
            return table
        }
        if let cached = cache.load() {
            return cached
        }
        return .fallback(now: now)
    }

    /// Reads the `rates` object. A payload is accepted only if every currency has a finite,
    /// positive rate. Entries for other codes are ignored, whatever their value.
    private static func parseRates(_ data: Data) -> [Currency: Double]? {
        guard let payload = try? JSONDecoder().decode(RatesPayload.self, from: data) else {
            return nil
        }
        var perUSD: [Currency: Double] = [:]
        for currency in Currency.allCases {
            guard let rate = payload.rates[currency.code]?.value,
                  rate.isFinite, rate > 0 else {
                return nil
            }
            perUSD[currency] = rate
        }
        // USD is the pivot, so it is exactly 1 whatever the payload says. The web tool hardcodes this too.
        perUSD[.usd] = 1
        return perUSD
    }
}

private struct RatesPayload: Decodable {
    let rates: [String: OptionalNumber]
}

/// A JSON number, or nil for any other JSON value. Lets unrelated entries be ignored.
private struct OptionalNumber: Decodable {
    let value: Double?

    init(from decoder: Decoder) throws {
        value = try? decoder.singleValueContainer().decode(Double.self)
    }
}
