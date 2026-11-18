import Foundation

/// Remembers the most recent successfully fetched rate table.
public protocol RateCaching: Sendable {
    func load() -> RateTable?
    func save(_ table: RateTable)
}

/// Caches the rate table as a JSON file. Writes replace the file atomically, and
/// failures are ignored because the cache is best effort.
public struct FileRateCache: RateCaching {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Returns nil when the file is missing, is not a rate table, or holds a table with
    /// a missing, zero, negative or non-finite rate.
    public func load() -> RateTable? {
        guard let data = try? Data(contentsOf: fileURL),
              let table = try? JSONDecoder().decode(RateTable.self, from: data),
              table.isUsable else {
            return nil
        }
        return table
    }

    public func save(_ table: RateTable) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        guard let data = try? encoder.encode(table) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
