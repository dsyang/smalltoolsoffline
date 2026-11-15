import SwiftUI
import WidgetKit

/// Home screen and lock screen widget showing the rates for a From / To currency pair.
struct CurrencyWidget: Widget {
    static let kind = "CurrencyWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: CurrencyConfigurationIntent.self,
            provider: CurrencyProvider()
        ) { entry in
            CurrencyWidgetView(entry: entry)
        }
        .configurationDisplayName("Currency Converter")
        .description("Rates for a currency pair. Tap to open the Currency Converter tool.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
