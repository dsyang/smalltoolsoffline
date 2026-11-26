import Foundation
import CurrencyCore

enum TestError: Error {
    case offline
}

/// Answers requests from a table keyed by absolute URL, and records every request.
/// Unknown URLs fail as if the network were down.
final class MockFetcher: HTTPFetching, @unchecked Sendable {
    private let lock = NSLock()
    private let responses: [String: Result<Data, Error>]
    private var requests: [String] = []

    init(_ responses: [String: Result<Data, Error>]) {
        self.responses = responses
    }

    var requestedURLs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    func data(from url: URL) async throws -> Data {
        guard let response = answer(for: url) else { throw TestError.offline }
        return try response.get()
    }

    /// Synchronous so the lock is never taken from an async context.
    private func answer(for url: URL) -> Result<Data, Error>? {
        lock.lock()
        defer { lock.unlock() }
        requests.append(url.absoluteString)
        return responses[url.absoluteString]
    }
}

/// In-memory RateCaching that records saves.
final class MemoryCache: RateCaching, @unchecked Sendable {
    private let lock = NSLock()
    private var table: RateTable?
    private var saves: [RateTable] = []

    init(_ table: RateTable? = nil) {
        self.table = table
    }

    var savedTables: [RateTable] {
        lock.lock()
        defer { lock.unlock() }
        return saves
    }

    func load() -> RateTable? {
        lock.lock()
        defer { lock.unlock() }
        return table
    }

    func save(_ table: RateTable) {
        lock.lock()
        defer { lock.unlock() }
        self.table = table
        saves.append(table)
    }
}

/// A complete, valid `rates` payload in the open.er-api.com shape. Values are raw JSON fragments.
func ratesPayload(_ values: [String: String]) -> Data {
    let entries = values.sorted { $0.key < $1.key }.map { "\"\($0.key)\": \($0.value)" }
    let json = "{\"result\": \"success\", \"base_code\": \"USD\", \"rates\": {\(entries.joined(separator: ", "))}}"
    return Data(json.utf8)
}

let completeRates: [String: String] = [
    "USD": "1", "EUR": "0.9", "GBP": "0.8", "TWD": "31.5", "JPY": "150.25", "CNY": "7.25", "CAD": "1.36",
]

/// A complete payload with some entries replaced.
func payload(overriding overrides: [String: String]) -> Data {
    ratesPayload(completeRates.merging(overrides) { _, new in new })
}

let primaryURL = "https://open.er-api.com/v6/latest/USD"
let secondaryURL = "https://api.exchangerate-api.com/v4/latest/USD"
