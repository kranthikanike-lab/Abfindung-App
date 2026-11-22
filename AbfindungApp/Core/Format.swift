import Foundation

enum Fmt {
    private static func makeFormatter(_ id: String) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = Locale(identifier: id)
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }
    private static let deFormatter = makeFormatter("de_DE")
    private static let enFormatter = makeFormatter("en_US")

    private static var localeId: String { Lang.shared.isEnglish ? "en_US" : "de_DE" }

    /// `1.234 €` in German, `1,234 €` in English (rounded like JS Math.round).
    static func eur(_ v: Double) -> String {
        let n = jsRound(v.isFinite ? v : 0)
        let f = Lang.shared.isEnglish ? enFormatter : deFormatter
        return (f.string(from: NSNumber(value: n)) ?? "0") + " €"
    }

    static func signedEur(_ v: Double) -> String {
        (v >= 0 ? "+ " : "− ") + eur(abs(v))
    }

    /// Decimal number with the decimal separator of the app language.
    static func decimal(_ v: Double, digits: Int = 1) -> String {
        String(format: "%.\(digits)f", locale: Locale(identifier: localeId), v)
    }

    static func pct(_ v: Double, digits: Int = 1) -> String {
        decimal(v, digits: digits) + " %"
    }
}
