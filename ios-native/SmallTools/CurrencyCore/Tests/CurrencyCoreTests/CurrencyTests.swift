import Foundation
import XCTest
import CurrencyCore

final class CurrencyTests: XCTestCase {
    func testCasesAndCodesMatchWebToolOrder() {
        XCTAssertEqual(Currency.allCases, [.usd, .eur, .gbp, .twd, .jpy, .cny, .cad])
        XCTAssertEqual(Currency.allCases.map(\.code), ["USD", "EUR", "GBP", "TWD", "JPY", "CNY", "CAD"])
    }

    func testSymbolsMatchWebTool() {
        XCTAssertEqual(Currency.usd.symbol, "$")
        XCTAssertEqual(Currency.eur.symbol, "€")
        XCTAssertEqual(Currency.gbp.symbol, "£")
        XCTAssertEqual(Currency.twd.symbol, "NT$")
        XCTAssertEqual(Currency.jpy.symbol, "¥")
        XCTAssertEqual(Currency.cny.symbol, "CN¥")
        XCTAssertEqual(Currency.cad.symbol, "C$")
    }

    func testDisplayNamesAreDistinctAndNonEmpty() {
        let names = Currency.allCases.map(\.displayName)
        XCTAssertTrue(names.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(Set(names).count, Currency.allCases.count)
        XCTAssertEqual(Currency.twd.displayName, "Taiwan Dollar (NTD)")
    }

    func testFractionDigitsAreZeroOnlyForJPY() {
        for currency in Currency.allCases {
            let expected = currency == .jpy ? 0 : 2
            XCTAssertEqual(currency.fractionDigits, expected, "\(currency)")
        }
        XCTAssertEqual(Currency.twd.fractionDigits, 2)
    }

    func testCodableUsesISOCodeAsRawValue() throws {
        let data = try JSONEncoder().encode([Currency.twd, Currency.jpy])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "[\"TWD\",\"JPY\"]")
        let decoded = try JSONDecoder().decode([Currency].self, from: data)
        XCTAssertEqual(decoded, [.twd, .jpy])
    }

    func testUnknownCodeFailsToDecode() {
        XCTAssertThrowsError(try JSONDecoder().decode([Currency].self, from: Data("[\"XYZ\"]".utf8)))
    }
}
