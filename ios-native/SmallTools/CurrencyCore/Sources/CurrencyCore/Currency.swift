/// The currencies supported by the converter. Raw values are ISO 4217 codes.
public enum Currency: String, CaseIterable, Codable, Sendable, Hashable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case twd = "TWD"
    case jpy = "JPY"
    case cny = "CNY"
    case cad = "CAD"

    /// ISO 4217 code, e.g. "USD".
    public var code: String { rawValue }

    /// Symbol as used by the web tool, e.g. "$", "NT$", "CN¥".
    public var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .twd: return "NT$"
        case .jpy: return "¥"
        case .cny: return "CN¥"
        case .cad: return "C$"
        }
    }

    public var displayName: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .twd: return "Taiwan Dollar (NTD)"
        case .jpy: return "Japanese Yen"
        case .cny: return "Chinese Yuan (RMB)"
        case .cad: return "Canadian Dollar"
        }
    }

    /// Digits shown after the decimal point. JPY and TWD are whole-unit currencies here.
    public var fractionDigits: Int {
        switch self {
        case .jpy, .twd: return 0
        case .usd, .eur, .gbp, .cny, .cad: return 2
        }
    }
}
