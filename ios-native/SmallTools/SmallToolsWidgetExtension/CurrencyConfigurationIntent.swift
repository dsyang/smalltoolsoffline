import AppIntents

/// Currencies offered in the widget's From and To pickers. The raw values are ISO codes.
/// `currency` maps each case to the CurrencyCore type used for all rate math.
enum CurrencyOption: String, AppEnum {
    case usd, eur, gbp, twd, jpy, cny, cad

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Currency"

    // Labels match the web tool's currency names (TWD is listed as NTD there).
    static var caseDisplayRepresentations: [CurrencyOption: DisplayRepresentation] = [
        .usd: "USD",
        .eur: "EUR",
        .gbp: "GBP",
        .twd: "TWD (NTD)",
        .jpy: "JPY",
        .cny: "CNY (RMB)",
        .cad: "CAD",
    ]

    var currency: Currency {
        switch self {
        case .usd: return .usd
        case .eur: return .eur
        case .gbp: return .gbp
        case .twd: return .twd
        case .jpy: return .jpy
        case .cny: return .cny
        case .cad: return .cad
        }
    }
}

/// Configuration for the widget: which currency to convert from and to.
struct CurrencyConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Currency Converter"
    static var description = IntentDescription("Choose the currency pair shown by the widget.")

    @Parameter(title: "From", default: .usd)
    var from: CurrencyOption

    @Parameter(title: "To", default: .twd)
    var to: CurrencyOption
}
