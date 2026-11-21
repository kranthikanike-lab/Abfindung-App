import Foundation

enum Fmt {
    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }()

    /// `1.234 €` (German grouping, rounded like JS Math.round).
    static func eur(_ v: Double) -> String {
        let n = jsRound(v.isFinite ? v : 0)
        return (intFormatter.string(from: NSNumber(value: n)) ?? "0") + " €"
    }

    static func signedEur(_ v: Double) -> String {
        (v >= 0 ? "+ " : "− ") + eur(abs(v))
    }

    static func pct(_ v: Double, digits: Int = 1) -> String {
        String(format: "%.\(digits)f", locale: Locale(identifier: "de_DE"), v) + " %"
    }

    static func months(_ m: Int) -> String { "\(m) Mon." }
}
