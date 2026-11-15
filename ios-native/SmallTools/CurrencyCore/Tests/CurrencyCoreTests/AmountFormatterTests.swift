import Foundation
import XCTest
import CurrencyCore

final class AmountFormatterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Symbols, decimals and grouping

    func testEveryCurrencyUsesItsSymbolAsPrefix() {
        for currency in Currency.allCases {
            XCTAssertTrue(AmountFormatter.format(1234.5, in: currency).hasPrefix(currency.symbol), "\(currency)")
        }
    }

    func testFormatsEachCurrency() {
        XCTAssertEqual(AmountFormatter.format(1234.5, in: .usd), "$1,234.50")
        XCTAssertEqual(AmountFormatter.format(1234.5, in: .eur), "€1,234.50")
        XCTAssertEqual(AmountFormatter.format(1234.5, in: .gbp), "£1,234.50")
        XCTAssertEqual(AmountFormatter.format(1234.5, in: .twd), "NT$1,235")
        XCTAssertEqual(AmountFormatter.format(1234.5, in: .jpy), "¥1,235")
        XCTAssertEqual(AmountFormatter.format(1234.5, in: .cny), "CN¥1,234.50")
        XCTAssertEqual(AmountFormatter.format(1234.5, in: .cad), "C$1,234.50")
    }

    func testWholeUnitCurrenciesHaveNoDecimals() {
        XCTAssertEqual(AmountFormatter.format(1000, in: .jpy), "¥1,000")
        XCTAssertEqual(AmountFormatter.format(32500, in: .twd), "NT$32,500")
    }

    func testTwoDecimalCurrenciesAlwaysShowCents() {
        XCTAssertEqual(AmountFormatter.format(100, in: .usd), "$100.00")
        XCTAssertEqual(AmountFormatter.format(12, in: .eur), "€12.00")
        XCTAssertEqual(AmountFormatter.format(0.5, in: .gbp), "£0.50")
        XCTAssertEqual(AmountFormatter.format(999.5, in: .usd), "$999.50")
        XCTAssertEqual(AmountFormatter.format(7.25, in: .cny), "CN¥7.25")
    }

    func testThousandsGrouping() {
        XCTAssertEqual(AmountFormatter.format(1000, in: .usd), "$1,000.00")
        XCTAssertEqual(AmountFormatter.format(1234567.891, in: .usd), "$1,234,567.89")
        XCTAssertEqual(AmountFormatter.format(1_000_000, in: .usd), "$1,000,000.00")
        XCTAssertEqual(AmountFormatter.format(1234567, in: .jpy), "¥1,234,567")
    }

    // MARK: Rounding (expected values are the web tool's toFixed/Math.round output, checked in Node)

    func testHalfwayAndNearHalfwayAmountsRoundLikeTheWebTool() {
        let cases: [(Double, String)] = [
            (0.125, "$0.13"),
            (0.375, "$0.38"),
            (1.005, "$1.00"),   // 1.005 is stored just below the tie, so it rounds down
            (2.675, "$2.67"),
            (0.005, "$0.01"),   // stored just above the tie, so it rounds up
            (9.995, "$9.99"),
            (0.001, "$0.00"),
            (0.0049, "$0.00"),
            (0.1 + 0.2, "$0.30"),
            (1.0 / 3.0, "$0.33"),
        ]
        for (amount, expected) in cases {
            XCTAssertEqual(AmountFormatter.format(amount, in: .usd), expected, "\(amount)")
        }
    }

    func testRoundingCarriesThroughDigitsAndGroups() {
        XCTAssertEqual(AmountFormatter.format(9.999, in: .usd), "$10.00")
        XCTAssertEqual(AmountFormatter.format(99.995, in: .usd), "$100.00")
        XCTAssertEqual(AmountFormatter.format(999.999, in: .usd), "$1,000.00")
        XCTAssertEqual(AmountFormatter.format(999.5, in: .jpy), "¥1,000")
    }

    func testWholeUnitHalfwayAmountsRoundUp() {
        XCTAssertEqual(AmountFormatter.format(2.5, in: .jpy), "¥3")
        XCTAssertEqual(AmountFormatter.format(0.5, in: .jpy), "¥1")
        XCTAssertEqual(AmountFormatter.format(1.5, in: .twd), "NT$2")
        XCTAssertEqual(AmountFormatter.format(1234.5, in: .jpy), "¥1,235")
        XCTAssertEqual(AmountFormatter.format(0.49999999999999994, in: .jpy), "¥0")
        XCTAssertEqual(AmountFormatter.format(0.4, in: .jpy), "¥0")
    }

    // MARK: Negative, zero and degenerate amounts

    func testNegativeAmountsKeepTheSignBeforeTheSymbol() {
        XCTAssertEqual(AmountFormatter.format(-1234.5, in: .usd), "-$1,234.50")
        XCTAssertEqual(AmountFormatter.format(-0.005, in: .usd), "-$0.01")
        XCTAssertEqual(AmountFormatter.format(-32500, in: .twd), "-NT$32,500")
        // Ties round away from zero for negatives too (the web tool's Math.round gives "¥-2" here).
        XCTAssertEqual(AmountFormatter.format(-2.5, in: .jpy), "-¥3")
    }

    func testAmountsThatRoundToZeroHaveNoSign() {
        XCTAssertEqual(AmountFormatter.format(-0.001, in: .usd), "$0.00")
        XCTAssertEqual(AmountFormatter.format(-0.0, in: .usd), "$0.00")
        XCTAssertEqual(AmountFormatter.format(-0.4, in: .jpy), "¥0")
    }

    func testZeroAmounts() {
        XCTAssertEqual(AmountFormatter.format(0, in: .usd), "$0.00")
        XCTAssertEqual(AmountFormatter.format(0, in: .jpy), "¥0")
        XCTAssertEqual(AmountFormatter.format(0, in: .twd), "NT$0")
        XCTAssertEqual(AmountFormatter.format(0, in: .cny), "CN¥0.00")
    }

    func testNonFiniteAmountsShowPlaceholder() {
        for currency in Currency.allCases {
            XCTAssertEqual(AmountFormatter.format(.nan, in: currency), "—", "\(currency)")
            XCTAssertEqual(AmountFormatter.format(.infinity, in: currency), "—", "\(currency)")
            XCTAssertEqual(AmountFormatter.format(-.infinity, in: currency), "—", "\(currency)")
        }
    }

    func testTinyAndSubnormalAmountsRoundToZero() {
        let tiny = [1e-300, Double.leastNormalMagnitude, Double.leastNonzeroMagnitude, -Double.leastNonzeroMagnitude]
        for amount in tiny {
            XCTAssertEqual(AmountFormatter.format(amount, in: .usd), "$0.00", "\(amount)")
            XCTAssertEqual(AmountFormatter.format(amount, in: .jpy), "¥0", "\(amount)")
        }
    }

    // MARK: Large amounts

    func testLargeAmountsKeepEveryDigit() {
        XCTAssertEqual(AmountFormatter.format(1e20, in: .usd), "$100,000,000,000,000,000,000.00")
        XCTAssertEqual(AmountFormatter.format(1e21, in: .usd), "$1,000,000,000,000,000,000,000.00")
        // 2^60 is exact in binary. The web tool's JPY column prints the shortest round-trip digits
        // ("1,152,921,504,606,847,000") instead; this formatter shows the value the double holds.
        XCTAssertEqual(AmountFormatter.format(pow(2, 60), in: .jpy), "¥1,152,921,504,606,846,976")
    }

    func testGreatestFiniteAmountFormatsWithoutTrapping() {
        let text = AmountFormatter.format(.greatestFiniteMagnitude, in: .usd)
        XCTAssertTrue(text.hasPrefix("$179,769,313,486,231,570,"), text)
        XCTAssertTrue(text.hasSuffix(".00"))
        XCTAssertEqual(text.filter { $0.isNumber }.count, 309 + 2)

        let negative = AmountFormatter.format(-.greatestFiniteMagnitude, in: .jpy)
        XCTAssertTrue(negative.hasPrefix("-¥179,769,313,486,231,570,"), negative)
    }

    func testFormattedCentsParseBackWithinHalfACent() {
        // Deterministic xorshift sequence, so failures reproduce exactly.
        var state: UInt64 = 0x2545_F491_4F6C_DD1D
        for _ in 0..<2_000 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            let unit = Double(state >> 11) / Double(UInt64(1) << 53)
            let amount = pow(10, unit * 9 - 3) // 1e-3 ... 1e6
            let text = AmountFormatter.format(amount, in: .usd)
            let number = Double(text.filter { $0.isNumber || $0 == "." })!
            XCTAssertLessThanOrEqual(abs(number - amount), 0.005 + 1e-9 * amount, "\(amount) -> \(text)")
        }
    }

    // MARK: Presets

    func testPresetsAreSixDistinctAscendingAmounts() {
        for currency in Currency.allCases {
            let presets = AmountFormatter.presets(for: currency)
            XCTAssertEqual(presets.count, 6, "\(currency)")
            XCTAssertEqual(presets, presets.sorted(), "\(currency)")
            XCTAssertEqual(Set(presets).count, 6, "\(currency)")
        }
    }

    func testPresetValuesPerCurrency() {
        let standard: [Double] = [1, 5, 10, 20, 50, 100]
        XCTAssertEqual(AmountFormatter.presets(for: .usd), standard)
        XCTAssertEqual(AmountFormatter.presets(for: .eur), standard)
        XCTAssertEqual(AmountFormatter.presets(for: .gbp), standard)
        XCTAssertEqual(AmountFormatter.presets(for: .cad), standard)
        XCTAssertEqual(AmountFormatter.presets(for: .cny), [10, 50, 100, 200, 500, 1000])
        XCTAssertEqual(AmountFormatter.presets(for: .jpy), [100, 500, 1000, 5000, 10000, 50000])
        XCTAssertEqual(AmountFormatter.presets(for: .twd), [100, 500, 1000, 2000, 5000, 10000])
    }

    func testWholeUnitPresetsAreIntegers() {
        for currency in [Currency.jpy, .twd] {
            XCTAssertTrue(AmountFormatter.presets(for: currency).allSatisfy { $0 == $0.rounded() }, "\(currency)")
        }
    }

    // MARK: Freshness label

    private func rateTable(ageSeconds: TimeInterval, isFallback: Bool = false) -> RateTable {
        RateTable(perUSD: RateTable.fallback(now: now).perUSD,
                  fetchedAt: now.addingTimeInterval(-ageSeconds),
                  isFallback: isFallback)
    }

    private func label(ageSeconds: TimeInterval) -> String {
        AmountFormatter.freshnessLabel(for: rateTable(ageSeconds: ageSeconds), now: now)
    }

    func testFreshnessJustNow() {
        XCTAssertEqual(label(ageSeconds: 0), "Updated just now")
        XCTAssertEqual(label(ageSeconds: 59.9), "Updated just now")
        // A timestamp in the future (clock skew) also reads as just now.
        XCTAssertEqual(label(ageSeconds: -300), "Updated just now")
    }

    func testFreshnessMinutes() {
        XCTAssertEqual(label(ageSeconds: 60), "Updated 1m ago")
        XCTAssertEqual(label(ageSeconds: 5 * 60), "Updated 5m ago")
        XCTAssertEqual(label(ageSeconds: 3_599), "Updated 59m ago")
    }

    func testFreshnessHours() {
        XCTAssertEqual(label(ageSeconds: 3_600), "Updated 1h ago")
        XCTAssertEqual(label(ageSeconds: 2 * 3_600), "Updated 2h ago")
        XCTAssertEqual(label(ageSeconds: 2 * 3_600 + 59 * 60), "Updated 2h ago")
        XCTAssertEqual(label(ageSeconds: 86_399), "Updated 23h ago")
    }

    func testFreshnessDays() {
        XCTAssertEqual(label(ageSeconds: 86_400), "Updated 1d ago")
        XCTAssertEqual(label(ageSeconds: 3 * 86_400), "Updated 3d ago")
    }

    func testFreshnessForAbsurdAgeDoesNotOverflow() {
        let ancient = RateTable(perUSD: RateTable.fallback(now: now).perUSD,
                                fetchedAt: Date(timeIntervalSince1970: -1e300),
                                isFallback: false)
        XCTAssertTrue(AmountFormatter.freshnessLabel(for: ancient, now: now).hasSuffix("d ago"))
    }

    func testFallbackTablesAreAlwaysOffline() {
        XCTAssertEqual(AmountFormatter.freshnessLabel(for: rateTable(ageSeconds: 0, isFallback: true), now: now),
                       "Offline rates")
        XCTAssertEqual(AmountFormatter.freshnessLabel(for: rateTable(ageSeconds: 30 * 86_400, isFallback: true), now: now),
                       "Offline rates")
        XCTAssertEqual(AmountFormatter.freshnessLabel(for: .fallback(now: now), now: now), "Offline rates")
    }

    func testNonFiniteTimestampIsUnknown() {
        let broken = RateTable(perUSD: RateTable.fallback(now: now).perUSD,
                               fetchedAt: Date(timeIntervalSince1970: .nan),
                               isFallback: false)
        XCTAssertEqual(AmountFormatter.freshnessLabel(for: broken, now: now), "Updated unknown")
    }
}
