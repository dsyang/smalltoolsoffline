import SwiftUI
import WidgetKit

/// Picks the layout for each family. The home screen families share a container background.
/// The lock screen family is tinted by the system, so it gets no background and no accent colors.
struct CurrencyWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CurrencyEntry

    /// Opens the Currency Converter tool (`tools/currency-universal.html`, slug `currency-universal`).
    private static let tapURL = URL(string: "smalltools://open/currency-universal")

    var body: some View {
        switch family {
        case .accessoryRectangular:
            CurrencyLockScreenView(entry: entry)
                .widgetURL(Self.tapURL)
        case .systemMedium:
            CurrencyMediumView(entry: entry)
                .containerBackground(CurrencyWidgetStyle.background, for: .widget)
                .widgetURL(Self.tapURL)
        default:
            CurrencySmallView(entry: entry)
                .containerBackground(CurrencyWidgetStyle.background, for: .widget)
                .widgetURL(Self.tapURL)
        }
    }
}

/// systemSmall: the pair, its rate, the first four preset amounts, and the freshness footer.
struct CurrencySmallView: View {
    let entry: CurrencyEntry

    var body: some View {
        let amounts = Array(AmountFormatter.presets(for: entry.from).prefix(4))
        VStack(alignment: .leading, spacing: 4) {
            CurrencyHeaderView(entry: entry)
            Divider()
            ForEach(amounts, id: \.self) { amount in
                CurrencyAmountRow(entry: entry, amount: amount)
            }
            Spacer(minLength: 0)
            CurrencyFreshnessLabel(entry: entry)
        }
    }
}

/// systemMedium: the pair and rate, the six preset amounts in a 2 x 3 grid, and the freshness footer.
struct CurrencyMediumView: View {
    let entry: CurrencyEntry

    var body: some View {
        let amounts = AmountFormatter.presets(for: entry.from)
        VStack(alignment: .leading, spacing: 6) {
            CurrencyHeaderView(entry: entry)
            HStack(alignment: .top, spacing: 16) {
                column(Array(amounts.prefix(3)))
                column(Array(amounts.dropFirst(3).prefix(3)))
            }
            Spacer(minLength: 0)
            CurrencyFreshnessLabel(entry: entry)
        }
    }

    private func column(_ amounts: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(amounts, id: \.self) { amount in
                CurrencyAmountRow(entry: entry, amount: amount)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// accessoryRectangular (lock screen): the pair, its rate, and the freshness label.
struct CurrencyLockScreenView: View {
    let entry: CurrencyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(entry.from.widgetLabel) → \(entry.to.widgetLabel)")
                .font(.headline)
                .lineLimit(1)
            Text(CurrencyWidgetStyle.rateLine(from: entry.from, to: entry.to, table: entry.table))
                .monospacedDigit()
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(AmountFormatter.freshnessLabel(for: entry.table, now: entry.date))
                .font(.caption2)
                .lineLimit(1)
        }
    }
}

/// "USD → NTD" in the source currency's accent color, with the current rate underneath.
struct CurrencyHeaderView: View {
    let entry: CurrencyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(entry.from.widgetLabel) → \(entry.to.widgetLabel)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(CurrencyWidgetStyle.accent(for: entry.from))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(CurrencyWidgetStyle.rateLine(from: entry.from, to: entry.to, table: entry.table))
                .monospacedDigit()
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// One preset: the source amount on the left, its conversion on the right.
struct CurrencyAmountRow: View {
    let entry: CurrencyEntry
    let amount: Double

    var body: some View {
        let converted = entry.table.convert(amount, from: entry.from, to: entry.to)
        HStack(spacing: 4) {
            Text(CurrencyWidgetStyle.amount(amount, in: entry.from))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Spacer(minLength: 2)
            Text(CurrencyWidgetStyle.amount(converted, in: entry.to))
                .monospacedDigit()
                .fontWeight(.medium)
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// Footer text from AmountFormatter, describing how fresh the rates are or that they are offline fallbacks.
struct CurrencyFreshnessLabel: View {
    let entry: CurrencyEntry

    var body: some View {
        Text(AmountFormatter.freshnessLabel(for: entry.table, now: entry.date))
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}
