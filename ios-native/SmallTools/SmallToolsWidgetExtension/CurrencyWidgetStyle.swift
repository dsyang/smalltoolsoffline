import Foundation
import SwiftUI
import UIKit

/// Colors and text formatting for the currency widget.
enum CurrencyWidgetStyle {
    /// Dark mode uses the web tool's surface color. Light mode uses the system background.
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? rgbColor(0x1A1D27) : UIColor.systemBackground
    })

    /// Per-currency accents from the web tool: USD green, EUR yellow, NTD pink, JPY blue.
    /// Light mode gets darker shades so they stay readable. GBP, CNY and CAD have no accent on
    /// the web tool, so they use the primary text color.
    static func accent(for currency: Currency) -> Color {
        switch currency {
        case .usd: return dynamicColor(light: 0x15803D, dark: 0x4ADE80)
        case .eur: return dynamicColor(light: 0xA16207, dark: 0xFACC15)
        case .twd: return dynamicColor(light: 0xBE185D, dark: 0xF472B6)
        case .jpy: return dynamicColor(light: 0x1D4ED8, dark: 0x60A5FA)
        case .gbp, .cny, .cad: return .primary
        }
    }

    /// "1 USD = 32.50 NTD".
    static func rateLine(from: Currency, to: Currency, table: RateTable) -> String {
        let rate = table.rate(from: from, to: to)
        guard rate.isFinite, rate > 0 else {
            return "1 \(from.widgetLabel) = — \(to.widgetLabel)"
        }
        let text = decimalString(rate, fractionDigits: rateDecimals(rate, to: to))
        return "1 \(from.widgetLabel) = \(text) \(to.widgetLabel)"
    }

    /// Four decimals under 1 so small rates stay readable. Otherwise the web tool's rate-chip precision
    /// for the target: JPY whole units, EUR and GBP four places, the rest two.
    private static func rateDecimals(_ rate: Double, to: Currency) -> Int {
        if rate < 1 { return 4 }
        switch to {
        case .jpy: return 0
        case .eur, .gbp: return 4
        case .usd, .twd, .cny, .cad: return 2
        }
    }

    /// Amount text from the shared formatter, used for preset source amounts and converted values.
    static func amount(_ value: Double, in currency: Currency) -> String {
        AmountFormatter.format(value, in: currency)
    }

    private static func dynamicColor(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            rgbColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func decimalString(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }
}

extension Currency {
    /// Short label used in the widget. The web tool shows TWD as NTD, so the widget does too.
    var widgetLabel: String {
        self == .twd ? "NTD" : code
    }
}

private func rgbColor(_ hex: UInt32) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}
