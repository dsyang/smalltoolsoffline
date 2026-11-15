import Foundation
import XCTest
import CurrencyCore

final class RateTableTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000.25)

    /// The web tool's FALLBACK_RATES, copied verbatim from currency-universal.html.
    private let webFallback: [Currency: Double] = [
        .usd: 1, .eur: 0.92, .gbp: 0.79, .twd: 32.5, .jpy: 150.0, .cny: 7.2, .cad: 1.37,
    ]

    private func table(_ perUSD: [Currency: Double]) -> RateTable {
        RateTable(perUSD: perUSD, fetchedAt: now, isFallback: false)
    }

    private func assertClose(_ actual: Double, _ expected: Double, relative: Double = 1e-12,
                             file: StaticString = #filePath, line: UInt = #line) {
        let tolerance = relative * max(1, abs(expected))
        XCTAssertLessThanOrEqual(abs(actual - expected), tolerance, "actual \(actual), expected \(expected)",
                                 file: file, line: line)
    }

    // MARK: Fallback table

    func testFallbackMatchesWebToolFallbackRates() {
        let fallback = RateTable.fallback(now: now)
        XCTAssertEqual(fallback.perUSD, webFallback)
        XCTAssertTrue(fallback.isFallback)
        XCTAssertEqual(fallback.fetchedAt, now)
    }

    // MARK: Pivot math

    func testRateFromUSDIsThePerUSDRate() {
        let fallback = RateTable.fallback(now: now)
        for currency in Currency.allCases {
            XCTAssertEqual(fallback.rate(from: .usd, to: currency), webFallback[currency]!, "\(currency)")
        }
    }

    func testRateToUSDIsTheInverseOfPerUSDRate() {
        let fallback = RateTable.fallback(now: now)
        for currency in Currency.allCases {
            assertClose(fallback.rate(from: currency, to: .usd), 1 / webFallback[currency]!)
        }
    }

    func testSameCurrencyRateIsExactlyOne() {
        let fallback = RateTable.fallback(now: now)
        for currency in Currency.allCases {
            XCTAssertEqual(fallback.rate(from: currency, to: currency), 1)
            XCTAssertEqual(fallback.convert(42.5, from: currency, to: currency), 42.5)
        }
    }

    func testCrossRatesPivotThroughUSD() {
        let fallback = RateTable.fallback(now: now)
        assertClose(fallback.rate(from: .eur, to: .jpy), 150.0 / 0.92)
        assertClose(fallback.rate(from: .twd, to: .cny), 7.2 / 32.5)
        assertClose(fallback.rate(from: .cad, to: .gbp), 0.79 / 1.37)
    }

    func testConvertMatchesWebToolFormulaExactly() {
        // Web tool: inUSD = value / rates[from]; result = inUSD * rates[to]
        let fallback = RateTable.fallback(now: now)
        let amounts: [Double] = [0.01, 1, 3.7, 1234.5, 987_654.321]
        for from in Currency.allCases {
            for to in Currency.allCases {
                for amount in amounts {
                    let webResult = (amount / webFallback[from]!) * webFallback[to]!
                    XCTAssertEqual(fallback.convert(amount, from: from, to: to), webResult,
                                   "\(amount) \(from) -> \(to)")
                }
            }
        }
    }

    func testConvertKnownValues() {
        let fallback = RateTable.fallback(now: now)
        assertClose(fallback.convert(100, from: .usd, to: .eur), 92)
        assertClose(fallback.convert(92, from: .eur, to: .usd), 100)
        assertClose(fallback.convert(1, from: .usd, to: .jpy), 150)
        assertClose(fallback.convert(32.5, from: .twd, to: .usd), 1)
    }

    func testRoundTripRecoversAmountForEveryPair() {
        let fallback = RateTable.fallback(now: now)
        for from in Currency.allCases {
            for to in Currency.allCases {
                for amount in [0.01, 1, 123.456, 1_000_000] {
                    let there = fallback.convert(amount, from: from, to: to)
                    let back = fallback.convert(there, from: to, to: from)
                    assertClose(back, amount)
                }
            }
        }
    }

    func testRateAndConvertAreConsistent() {
        let fallback = RateTable.fallback(now: now)
        assertClose(fallback.convert(250, from: .gbp, to: .twd), 250 * fallback.rate(from: .gbp, to: .twd))
    }

    // MARK: Edge amounts

    func testZeroAndNegativeAmounts() {
        let fallback = RateTable.fallback(now: now)
        XCTAssertEqual(fallback.convert(0, from: .usd, to: .eur), 0)
        assertClose(fallback.convert(-10, from: .usd, to: .eur), -9.2)
        assertClose(fallback.convert(-9.2, from: .eur, to: .usd), -10)
    }

    func testNonFiniteAmountsPropagateWithoutCrashing() {
        let fallback = RateTable.fallback(now: now)
        XCTAssertTrue(fallback.convert(.nan, from: .usd, to: .eur).isNaN)
        XCTAssertEqual(fallback.convert(.infinity, from: .usd, to: .eur), .infinity)
        XCTAssertEqual(fallback.convert(-.infinity, from: .usd, to: .jpy), -.infinity)
    }

    // MARK: Unusable rates

    func testMissingRateYieldsNaN() {
        var perUSD = webFallback
        perUSD[.twd] = nil
        let broken = table(perUSD)
        XCTAssertTrue(broken.rate(from: .usd, to: .twd).isNaN)
        XCTAssertTrue(broken.rate(from: .twd, to: .usd).isNaN)
        XCTAssertTrue(broken.convert(10, from: .usd, to: .twd).isNaN)
        assertClose(broken.rate(from: .usd, to: .eur), 0.92)
    }

    func testZeroNegativeAndNonFiniteRatesYieldNaN() {
        let unusable: [Double] = [0, -1, .nan, .infinity, -.infinity]
        for bad in unusable {
            var perUSD = webFallback
            perUSD[.gbp] = bad
            let broken = table(perUSD)
            XCTAssertTrue(broken.rate(from: .usd, to: .gbp).isNaN, "rate \(bad)")
            XCTAssertTrue(broken.rate(from: .gbp, to: .usd).isNaN, "rate \(bad)")
            XCTAssertTrue(broken.rate(from: .gbp, to: .gbp).isNaN, "same-currency rate \(bad)")
            XCTAssertTrue(broken.convert(5, from: .gbp, to: .eur).isNaN, "convert \(bad)")
        }
    }

    // MARK: JSON codec

    func testJSONRoundTripPreservesTable() throws {
        let original = RateTable(perUSD: webFallback, fetchedAt: now, isFallback: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RateTable.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.fetchedAt.timeIntervalSince1970, now.timeIntervalSince1970)
    }

    func testFallbackJSONRoundTripKeepsFallbackFlag() throws {
        let original = RateTable.fallback(now: now)
        let decoded = try JSONDecoder().decode(RateTable.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.isFallback)
    }

    func testJSONUsesCurrencyCodeKeysNotPairs() throws {
        struct Shape: Decodable {
            let perUSD: [String: Double]
            let fetchedAt: Double
            let isFallback: Bool
        }
        let data = try JSONEncoder().encode(RateTable(perUSD: webFallback, fetchedAt: now, isFallback: false))
        let shape = try JSONDecoder().decode(Shape.self, from: data)
        XCTAssertEqual(Set(shape.perUSD.keys), Set(Currency.allCases.map(\.code)))
        XCTAssertEqual(shape.perUSD["TWD"], 32.5)
        XCTAssertEqual(shape.fetchedAt, 1_800_000_000.25)
        XCTAssertFalse(shape.isFallback)
    }

    func testDecodingIgnoresUnknownCurrencyCodes() throws {
        let json = """
        {"perUSD": {"USD": 1, "EUR": 0.92, "GBP": 0.79, "TWD": 32.5, "JPY": 150, "CNY": 7.2, "CAD": 1.37, "XYZ": 3},
         "fetchedAt": 1800000000, "isFallback": false}
        """
        let decoded = try JSONDecoder().decode(RateTable.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.perUSD.count, Currency.allCases.count)
        XCTAssertEqual(decoded.perUSD, webFallback)
    }

    func testDecodingRejectsMissingFieldsAndNonNumericRates() {
        let missingFlag = #"{"perUSD": {"USD": 1}, "fetchedAt": 1800000000}"#
        let stringRate = #"{"perUSD": {"USD": "1"}, "fetchedAt": 1800000000, "isFallback": false}"#
        XCTAssertThrowsError(try JSONDecoder().decode(RateTable.self, from: Data(missingFlag.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(RateTable.self, from: Data(stringRate.utf8)))
    }
}
