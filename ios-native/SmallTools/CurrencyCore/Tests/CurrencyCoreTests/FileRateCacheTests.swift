import Foundation
import XCTest
import CurrencyCore

final class FileRateCacheTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000.5)
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CurrencyCoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var fileURL: URL {
        directory.appendingPathComponent("rates.json")
    }

    private func sampleTable(isFallback: Bool = false) -> RateTable {
        RateTable(perUSD: RateTable.fallback(now: now).perUSD, fetchedAt: now, isFallback: isFallback)
    }

    private func write(_ data: Data) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL)
    }

    /// The JSON the cache would write for `table`, as a dictionary the tests can edit.
    private func jsonObject(for table: RateTable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(table)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func data(from object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    // MARK: Save and load

    func testSaveThenLoadRoundTrips() {
        let cache = FileRateCache(fileURL: fileURL)
        let table = sampleTable()
        cache.save(table)
        XCTAssertEqual(cache.load(), table)
    }

    func testSaveCreatesMissingParentDirectories() {
        let nested = directory.appendingPathComponent("a/b/c/rates.json")
        let cache = FileRateCache(fileURL: nested)
        cache.save(sampleTable())
        XCTAssertNotNil(cache.load())
    }

    func testSaveOverwritesPreviousTable() {
        let cache = FileRateCache(fileURL: fileURL)
        cache.save(sampleTable())
        var newer = sampleTable()
        newer.fetchedAt = now.addingTimeInterval(3_600)
        newer.perUSD[.eur] = 0.5
        cache.save(newer)
        XCTAssertEqual(cache.load(), newer)
    }

    func testSaveLeavesOnlyTheCacheFileBehind() throws {
        FileRateCache(fileURL: fileURL).save(sampleTable())
        FileRateCache(fileURL: fileURL).save(sampleTable())
        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(contents, ["rates.json"])
    }

    func testSavedBytesAreStableAcrossSaves() throws {
        let cache = FileRateCache(fileURL: fileURL)
        cache.save(sampleTable())
        let first = try Data(contentsOf: fileURL)
        cache.save(sampleTable())
        XCTAssertEqual(try Data(contentsOf: fileURL), first)
    }

    func testSavedFileIsReadableJSONKeyedByCurrencyCode() throws {
        FileRateCache(fileURL: fileURL).save(sampleTable(isFallback: true))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any])
        let rates = try XCTUnwrap(object["perUSD"] as? [String: Any])
        XCTAssertEqual(Set(rates.keys), Set(Currency.allCases.map(\.code)))
        XCTAssertEqual(object["isFallback"] as? Bool, true)
        XCTAssertEqual(object["fetchedAt"] as? Double, 1_800_000_000.5)
    }

    func testSaveNonFiniteTableWritesNothing() {
        var broken = sampleTable()
        broken.perUSD[.gbp] = .nan
        FileRateCache(fileURL: fileURL).save(broken)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertNil(FileRateCache(fileURL: fileURL).load())
    }

    func testSaveToUnwritableLocationIsSilent() {
        // A regular file where the cache directory should be makes every write fail.
        try? FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.createFile(atPath: directory.path, contents: Data()))
        let cache = FileRateCache(fileURL: fileURL)
        cache.save(sampleTable())
        XCTAssertNil(cache.load())
    }

    // MARK: Missing and corrupt files

    func testLoadReturnsNilWhenFileIsMissing() {
        XCTAssertNil(FileRateCache(fileURL: fileURL).load())
    }

    func testLoadReturnsNilForBinaryGarbage() throws {
        try write(Data([0xFF, 0x00, 0xD8, 0x12, 0x80]))
        XCTAssertNil(FileRateCache(fileURL: fileURL).load())
    }

    func testLoadReturnsNilForTruncatedJSON() throws {
        let full = try JSONEncoder().encode(sampleTable())
        try write(full.prefix(full.count / 2))
        XCTAssertNil(FileRateCache(fileURL: fileURL).load())
    }

    func testLoadReturnsNilForEmptyFile() throws {
        try write(Data())
        XCTAssertNil(FileRateCache(fileURL: fileURL).load())
    }

    func testLoadReturnsNilForWrongShape() throws {
        try write(Data(#"["USD", "EUR"]"#.utf8))
        XCTAssertNil(FileRateCache(fileURL: fileURL).load())
    }

    func testLoadReturnsNilWhenACurrencyIsMissing() throws {
        var object = try jsonObject(for: sampleTable())
        var rates = try XCTUnwrap(object["perUSD"] as? [String: Double])
        rates["CAD"] = nil
        object["perUSD"] = rates
        try write(try data(from: object))
        XCTAssertNil(FileRateCache(fileURL: fileURL).load())
    }

    func testLoadReturnsNilForZeroOrNegativeRate() throws {
        for bad in [0.0, -150.0] {
            var object = try jsonObject(for: sampleTable())
            var rates = try XCTUnwrap(object["perUSD"] as? [String: Double])
            rates["JPY"] = bad
            object["perUSD"] = rates
            try write(try data(from: object))
            XCTAssertNil(FileRateCache(fileURL: fileURL).load(), "rate \(bad)")
        }
    }

    func testLoadReturnsNilForNonFiniteTimestamp() throws {
        // 1e999 overflows Double, so the table cannot be trusted.
        let json = #"{"perUSD": {"USD": 1, "EUR": 0.92, "GBP": 0.79, "TWD": 32.5, "JPY": 150, "CNY": 7.2, "CAD": 1.37}, "fetchedAt": 1e999, "isFallback": false}"#
        try write(Data(json.utf8))
        XCTAssertNil(FileRateCache(fileURL: fileURL).load())
    }

    func testLoadAcceptsExtraCurrencyCodesFromNewerBuilds() throws {
        var object = try jsonObject(for: sampleTable())
        var rates = try XCTUnwrap(object["perUSD"] as? [String: Double])
        rates["XYZ"] = 9
        object["perUSD"] = rates
        try write(try data(from: object))
        XCTAssertEqual(FileRateCache(fileURL: fileURL).load()?.perUSD.count, Currency.allCases.count)
    }
}
