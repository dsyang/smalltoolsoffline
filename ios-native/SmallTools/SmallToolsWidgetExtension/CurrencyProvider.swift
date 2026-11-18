import Foundation
import WidgetKit

/// One rendered state of the widget: the rates plus the configured pair.
struct CurrencyEntry: TimelineEntry, Sendable {
    let date: Date
    let table: RateTable
    let from: Currency
    let to: Currency
}

struct CurrencyProvider: AppIntentTimelineProvider {
    /// How long WidgetKit should wait before asking for a new timeline.
    static let refreshInterval: TimeInterval = 3 * 60 * 60

    /// Spacing between entries inside one timeline. Each entry's freshness label is computed at its own
    /// date, so "Updated 30m ago" advances without waiting for the next reload.
    static let entryInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> CurrencyEntry {
        let now = Date()
        return CurrencyEntry(date: now, table: .fallback(now: now), from: .usd, to: .twd)
    }

    /// Used for the widget gallery and the add-widget preview, so it makes no network request.
    func snapshot(for configuration: CurrencyConfigurationIntent, in context: Context) async -> CurrencyEntry {
        let now = Date()
        return CurrencyEntry(
            date: now,
            table: .fallback(now: now),
            from: configuration.from.currency,
            to: configuration.to.currency
        )
    }

    /// RateProvider never throws. It returns live rates, else the last good cached rates, else the
    /// built-in fallback table, so the timeline always has at least one entry, even offline.
    func timeline(for configuration: CurrencyConfigurationIntent, in context: Context) async -> Timeline<CurrencyEntry> {
        let now = Date()
        let table = await RateProvider.loadRates(
            fetcher: URLSessionFetcher(),
            cache: FileRateCache(fileURL: Self.cacheFileURL),
            now: now
        )
        let source = configuration.from.currency
        let target = configuration.to.currency
        let entries = stride(from: 0.0, to: Self.refreshInterval, by: Self.entryInterval).map { offset in
            CurrencyEntry(date: now.addingTimeInterval(offset), table: table, from: source, to: target)
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(Self.refreshInterval)))
    }

    /// The widget has no App Group, so it keeps its own copy of the last good rates in its caches directory.
    private static var cacheFileURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("rates.json")
    }
}
