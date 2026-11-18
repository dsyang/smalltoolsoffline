import Foundation

/// Formats amounts, supplies the widget's preset amounts, and labels how fresh the rates are.
/// Output is hardcoded to en_US conventions and never consults the host locale, so it is the
/// same on Linux and iOS.
public enum AmountFormatter {
    /// Shown in place of an amount that is NaN or infinite.
    private static let placeholder = "—"

    /// Formats `amount` as the web tool does: currency symbol, en_US thousands grouping and
    /// `fractionDigits` decimals. For example "$1,234.50", "¥1,000", "NT$32,500.00".
    ///
    /// Rounding is decided on the exact binary value, as JavaScript's toFixed does, so 1.005
    /// shows as "$1.00" and 0.125 as "$0.13". Ties round away from zero. A negative amount gets
    /// a leading minus sign, and a value that rounds to zero never shows one.
    public static func format(_ amount: Double, in currency: Currency) -> String {
        guard amount.isFinite else { return placeholder }
        let rounded = roundHalfAwayFromZero(magnitude: abs(amount), fractionDigits: currency.fractionDigits)
        let isZero = rounded.integer.allSatisfy { $0 == 0 } && rounded.fraction.allSatisfy { $0 == 0 }
        let sign = amount < 0 && !isZero ? "-" : ""
        var number = groupThousands(rounded.integer)
        if currency.fractionDigits > 0 {
            number += "." + String(rounded.fraction.map(digitCharacter))
        }
        return sign + currency.symbol + number
    }

    /// Preset source amounts for the widget grid. Always six values, in ascending order.
    public static func presets(for currency: Currency) -> [Double] {
        switch currency {
        case .usd, .eur, .gbp, .cad: return [1, 5, 10, 20, 50, 100]
        case .cny: return [10, 50, 100, 200, 500, 1000]
        case .jpy: return [100, 500, 1000, 5000, 10000, 50000]
        case .twd: return [100, 500, 1000, 2000, 5000, 10000]
        }
    }

    /// "Updated just now", "Updated 5m ago", "Updated 2h ago", "Updated 3d ago", or
    /// "Offline rates" for a fallback table.
    public static func freshnessLabel(for table: RateTable, now: Date) -> String {
        if table.isFallback {
            return "Offline rates"
        }
        let age = now.timeIntervalSince(table.fetchedAt)
        guard age.isFinite else { return "Updated unknown" }
        // Clamp so a timestamp in the future reads as "just now" and an absurd age cannot overflow Int.
        let seconds = min(max(age, 0), 1e15)
        if seconds < 60 {
            return "Updated just now"
        }
        if seconds < 3_600 {
            return "Updated \(Int(seconds / 60))m ago"
        }
        if seconds < 86_400 {
            return "Updated \(Int(seconds / 3_600))h ago"
        }
        return "Updated \(Int(seconds / 86_400))d ago"
    }

    // MARK: Rounding and grouping

    /// Rounds a finite, non-negative value to `fractionDigits` decimals, ties away from zero.
    private static func roundHalfAwayFromZero(magnitude: Double, fractionDigits: Int)
        -> (integer: [UInt8], fraction: [UInt8]) {
        let exact = exactDecimal(of: magnitude)
        var kept = exact.integer
        for index in 0..<fractionDigits {
            kept.append(index < exact.fraction.count ? exact.fraction[index] : 0)
        }
        // The exact expansion is finite, so the first dropped digit decides ties and everything else.
        let firstDropped = fractionDigits < exact.fraction.count ? exact.fraction[fractionDigits] : 0
        if firstDropped >= 5 {
            incrementDecimal(&kept)
        }
        let integerCount = kept.count - fractionDigits
        return (Array(kept[..<integerCount]), Array(kept[integerCount...]))
    }

    /// Adds one to a decimal digit string in place, growing it when every digit carries.
    private static func incrementDecimal(_ digits: inout [UInt8]) {
        var index = digits.count - 1
        while index >= 0 {
            if digits[index] < 9 {
                digits[index] += 1
                return
            }
            digits[index] = 0
            index -= 1
        }
        digits.insert(1, at: 0)
    }

    /// Inserts a comma between each group of three integer digits, en_US style.
    private static func groupThousands(_ integer: [UInt8]) -> String {
        var result = ""
        for (index, digit) in integer.enumerated() {
            if index > 0 && (integer.count - index) % 3 == 0 {
                result.append(",")
            }
            result.append(digitCharacter(digit))
        }
        return result
    }

    private static func digitCharacter(_ digit: UInt8) -> Character {
        Character(Unicode.Scalar(UInt8(ascii: "0") + digit))
    }

    /// The exact decimal expansion of a finite, non-negative Double, split at the decimal point.
    /// Every binary fraction has a finite decimal expansion, so no precision is lost.
    private static func exactDecimal(of value: Double) -> (integer: [UInt8], fraction: [UInt8]) {
        let bits = value.bitPattern
        let biasedExponent = Int((bits >> 52) & 0x7FF)
        var significand = bits & ((1 << 52) - 1)
        var exponent: Int
        if biasedExponent == 0 {
            exponent = -1074 // subnormal: no implicit leading bit
        } else {
            significand |= 1 << 52
            exponent = biasedExponent - 1075
        }
        guard significand != 0 else { return ([0], []) }

        // Dropping trailing zero bits keeps the power of five below small.
        while exponent < 0 && significand & 1 == 0 {
            significand >>= 1
            exponent += 1
        }

        // value = significand * 2^exponent
        var number = ExactInteger(significand)
        let fractionLength: Int
        if exponent >= 0 {
            number.multiplyByPowerOfTwo(exponent)
            fractionLength = 0
        } else {
            // significand / 2^k == significand * 5^k / 10^k
            number.multiplyByPowerOfFive(-exponent)
            fractionLength = -exponent
        }

        var digits = number.decimalDigits
        if digits.count <= fractionLength {
            digits.insert(contentsOf: repeatElement(0, count: fractionLength + 1 - digits.count), at: 0)
        }
        let split = digits.count - fractionLength
        return (Array(digits[..<split]), Array(digits[split...]))
    }
}

/// Unsigned integer in base 10^9 (little-endian limbs), just big enough to expand binary
/// fractions exactly. Not a general-purpose big integer.
private struct ExactInteger {
    private static let base: UInt64 = 1_000_000_000
    private var limbs: [UInt64]

    init(_ value: UInt64) {
        limbs = []
        var remaining = value
        repeat {
            limbs.append(remaining % ExactInteger.base)
            remaining /= ExactInteger.base
        } while remaining > 0
    }

    /// Multiplies in place. `factor` must be below 2^31 so each product fits in UInt64.
    mutating func multiply(by factor: UInt64) {
        var carry: UInt64 = 0
        for index in limbs.indices {
            let product = limbs[index] * factor + carry
            limbs[index] = product % ExactInteger.base
            carry = product / ExactInteger.base
        }
        while carry > 0 {
            limbs.append(carry % ExactInteger.base)
            carry /= ExactInteger.base
        }
    }

    mutating func multiplyByPowerOfTwo(_ exponent: Int) {
        var remaining = exponent
        while remaining > 0 {
            let step = min(remaining, 29)
            multiply(by: UInt64(1) << step)
            remaining -= step
        }
    }

    mutating func multiplyByPowerOfFive(_ exponent: Int) {
        var remaining = exponent
        while remaining > 0 {
            let step = min(remaining, 13) // 5^13 < 2^31
            var factor: UInt64 = 1
            for _ in 0..<step {
                factor *= 5
            }
            multiply(by: factor)
            remaining -= step
        }
    }

    /// Decimal digits, most significant first.
    var decimalDigits: [UInt8] {
        var digits: [UInt8] = []
        for (position, limb) in limbs.reversed().enumerated() {
            var chunk = [UInt8](repeating: 0, count: 9)
            var remaining = limb
            for index in stride(from: 8, through: 0, by: -1) {
                chunk[index] = UInt8(remaining % 10)
                remaining /= 10
            }
            if position == 0 {
                digits = Array(chunk.drop(while: { $0 == 0 }))
            } else {
                digits += chunk
            }
        }
        return digits.isEmpty ? [0] : digits
    }
}
