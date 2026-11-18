import Foundation
import XCTest
import CurrencyCore

final class RateProviderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Outcome {
        let table: RateTable
        let fetcher: MockFetcher
        let cache: MemoryCache
    }

    private func load(_ responses: [String: Result<Data, Error>], cache: MemoryCache = MemoryCache()) async -> Outcome {
        let fetcher = MockFetcher(responses)
        let table = await RateProvider.loadRates(fetcher: fetcher, cache: cache, now: now)
        return Outcome(table: table, fetcher: fetcher, cache: cache)
    }

    /// Primary source answers with `body`; secondary is down.
    private func primaryOnly(_ body: Data) async -> Outcome {
        await load([primaryURL: .success(body)])
    }

    private func assertFallsThroughToFallback(_ outcome: Outcome, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(outcome.table, RateTable.fallback(now: now), file: file, line: line)
        XCTAssertTrue(outcome.table.isFallback, file: file, line: line)
        XCTAssertTrue(outcome.cache.savedTables.isEmpty, file: file, line: line)
    }

    // MARK: Source order and success

    func testPrimarySourceSucceedsAndIsCached() async {
        let outcome = await load([primaryURL: .success(payload(overriding: [:]))])
        XCTAssertFalse(outcome.table.isFallback)
        XCTAssertEqual(outcome.table.fetchedAt, now)
        XCTAssertEqual(outcome.table.perUSD[.usd], 1)
        XCTAssertEqual(outcome.table.perUSD[.eur], 0.9)
        XCTAssertEqual(outcome.table.perUSD[.gbp], 0.8)
        XCTAssertEqual(outcome.table.perUSD[.twd], 31.5)
        XCTAssertEqual(outcome.table.perUSD[.jpy], 150.25)
        XCTAssertEqual(outcome.table.perUSD[.cny], 7.25)
        XCTAssertEqual(outcome.table.perUSD[.cad], 1.36)
        XCTAssertEqual(outcome.fetcher.requestedURLs, [primaryURL])
        XCTAssertEqual(outcome.cache.savedTables, [outcome.table])
    }

    func testSecondarySourceUsedWhenPrimaryFails() async {
        let outcome = await load([secondaryURL: .success(payload(overriding: ["EUR": "0.85"]))])
        XCTAssertFalse(outcome.table.isFallback)
        XCTAssertEqual(outcome.table.perUSD[.eur], 0.85)
        XCTAssertEqual(outcome.fetcher.requestedURLs, [primaryURL, secondaryURL])
        XCTAssertEqual(outcome.cache.savedTables, [outcome.table])
    }

    func testPrimaryErrorThenSecondarySucceeds() async {
        let outcome = await load([
            primaryURL: .failure(TestError.offline),
            secondaryURL: .success(payload(overriding: [:])),
        ])
        XCTAssertFalse(outcome.table.isFallback)
        XCTAssertEqual(outcome.fetcher.requestedURLs, [primaryURL, secondaryURL])
    }

    func testPrimarySucceedsSoSecondaryIsNeverCalled() async {
        let outcome = await load([
            primaryURL: .success(payload(overriding: [:])),
            secondaryURL: .success(payload(overriding: ["EUR": "0.1"])),
        ])
        XCTAssertEqual(outcome.fetcher.requestedURLs, [primaryURL])
        XCTAssertEqual(outcome.table.perUSD[.eur], 0.9)
    }

    // MARK: Failure paths

    func testBothSourcesFailWithCacheReturnsCachedTable() async {
        let cached = RateTable(perUSD: RateTable.fallback(now: now).perUSD,
                               fetchedAt: now.addingTimeInterval(-7_200), isFallback: false)
        let outcome = await load([:], cache: MemoryCache(cached))
        XCTAssertEqual(outcome.table, cached)
        XCTAssertFalse(outcome.table.isFallback)
        XCTAssertEqual(outcome.fetcher.requestedURLs, [primaryURL, secondaryURL])
        XCTAssertTrue(outcome.cache.savedTables.isEmpty, "a failed load must not overwrite the cache")
    }

    func testBothSourcesFailWithoutCacheReturnsFallback() async {
        let outcome = await load([:])
        XCTAssertTrue(outcome.table.isFallback)
        XCTAssertEqual(outcome.table.fetchedAt, now)
        XCTAssertEqual(outcome.table, RateTable.fallback(now: now))
        XCTAssertTrue(outcome.cache.savedTables.isEmpty)
    }

    func testCacheIsPreferredOverFallbackEvenWhenVeryOld() async {
        let ancient = RateTable(perUSD: RateTable.fallback(now: now).perUSD,
                                fetchedAt: Date(timeIntervalSince1970: 1_000_000), isFallback: false)
        let outcome = await load([:], cache: MemoryCache(ancient))
        XCTAssertEqual(outcome.table, ancient)
    }

    func testFetcherErrorsNeverEscape() async {
        // Every source throws a different error; the call must still return a table.
        let outcome = await load([
            primaryURL: .failure(TestError.offline),
            secondaryURL: .failure(URLError(.timedOut)),
        ])
        XCTAssertTrue(outcome.table.isFallback)
    }

    // MARK: Payload validation

    func testMalformedJSONIsRejected() async {
        let outcome = await primaryOnly(Data("<html>rate limited</html>".utf8))
        assertFallsThroughToFallback(outcome)
    }

    func testEmptyBodyIsRejected() async {
        assertFallsThroughToFallback(await primaryOnly(Data()))
    }

    func testTopLevelArrayIsRejected() async {
        assertFallsThroughToFallback(await primaryOnly(Data("[1, 2, 3]".utf8)))
    }

    func testErrorPayloadWithoutRatesIsRejected() async {
        let body = Data(#"{"result": "error", "error-type": "unsupported-code"}"#.utf8)
        assertFallsThroughToFallback(await primaryOnly(body))
    }

    func testRatesNotAnObjectIsRejected() async {
        assertFallsThroughToFallback(await primaryOnly(Data(#"{"rates": [1, 2]}"#.utf8)))
    }

    func testPartialPayloadIsRejected() async {
        var values = completeRates
        values["TWD"] = nil
        assertFallsThroughToFallback(await primaryOnly(ratesPayload(values)))
    }

    func testMissingUSDIsRejected() async {
        var values = completeRates
        values["USD"] = nil
        assertFallsThroughToFallback(await primaryOnly(ratesPayload(values)))
    }

    func testZeroRateIsRejected() async {
        assertFallsThroughToFallback(await primaryOnly(payload(overriding: ["JPY": "0"])))
    }

    func testNegativeRateIsRejected() async {
        assertFallsThroughToFallback(await primaryOnly(payload(overriding: ["GBP": "-0.8"])))
    }

    func testNullRateIsRejected() async {
        assertFallsThroughToFallback(await primaryOnly(payload(overriding: ["CAD": "null"])))
    }

    func testStringRateIsRejected() async {
        assertFallsThroughToFallback(await primaryOnly(payload(overriding: ["CNY": "\"7.25\""])))
    }

    func testNestedRateValueIsRejected() async {
        assertFallsThroughToFallback(await primaryOnly(payload(overriding: ["EUR": "{\"value\": 0.9}"])))
    }

    func testOverflowingRateIsRejected() async {
        // 1e999 is outside Double's range, so it must never become a usable rate.
        assertFallsThroughToFallback(await primaryOnly(payload(overriding: ["EUR": "1e999"])))
    }

    func testInvalidPrimaryFallsThroughToValidSecondary() async {
        let outcome = await load([
            primaryURL: .success(payload(overriding: ["JPY": "0"])),
            secondaryURL: .success(payload(overriding: ["JPY": "149"])),
        ])
        XCTAssertFalse(outcome.table.isFallback)
        XCTAssertEqual(outcome.table.perUSD[.jpy], 149)
        XCTAssertEqual(outcome.fetcher.requestedURLs, [primaryURL, secondaryURL])
        XCTAssertEqual(outcome.cache.savedTables.count, 1)
    }

    func testUnrelatedEntriesAreIgnored() async {
        let body = payload(overriding: [
            "BTC": "\"not a number\"",
            "XAU": "null",
            "ZZZ": "{\"nested\": [1, 2]}",
            "ABC": "[1, 2]",
        ])
        let outcome = await primaryOnly(body)
        XCTAssertFalse(outcome.table.isFallback)
        XCTAssertEqual(outcome.table.perUSD.count, Currency.allCases.count)
    }

    func testUSDIsPinnedToOneEvenIfPayloadDiffers() async {
        let outcome = await primaryOnly(payload(overriding: ["USD": "1.0000002"]))
        XCTAssertFalse(outcome.table.isFallback)
        XCTAssertEqual(outcome.table.perUSD[.usd], 1)
    }

    // MARK: Timestamps

    func testDefaultNowIsCurrentTime() async {
        let before = Date()
        let fetcher = MockFetcher([primaryURL: .success(payload(overriding: [:]))])
        let table = await RateProvider.loadRates(fetcher: fetcher, cache: MemoryCache())
        XCTAssertGreaterThanOrEqual(table.fetchedAt, before)
        XCTAssertLessThanOrEqual(table.fetchedAt, Date())
    }
}
