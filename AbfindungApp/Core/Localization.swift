import Foundation
import Observation

/// In-app language (German / English). Defaults to the iPhone language; the user can override it in the app menu.
@Observable
final class Lang {
    static let shared = Lang()
    private static let storeKey = "abfindungs_optimizer_lang_v1"

    /// "de" or "en"
    var code: String {
        didSet { UserDefaults.standard.set(code, forKey: Self.storeKey) }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.storeKey), saved == "de" || saved == "en" {
            code = saved
        } else {
            code = (Locale.preferredLanguages.first ?? "de").hasPrefix("de") ? "de" : "en"
        }
    }

    var isEnglish: Bool { code == "en" }
}

/// A translatable text. String interpolation is captured: every `\(value)` becomes a "%@" placeholder in the lookup key,
/// so `tr("Jahresbrutto: \(x)")` finds the entry "Jahresbrutto: %@" and puts the value back in.
struct LKey: ExpressibleByStringInterpolation {
    var format: String
    var args: [String]

    init(stringLiteral value: String) {
        format = value
        args = []
    }

    init(stringInterpolation: Interpolation) {
        format = stringInterpolation.format
        args = stringInterpolation.args
    }

    struct Interpolation: StringInterpolationProtocol {
        var format = ""
        var args: [String] = []

        init(literalCapacity: Int, interpolationCount: Int) {}

        mutating func appendLiteral(_ literal: String) { format += literal }

        mutating func appendInterpolation<T>(_ value: T) {
            format += "%@"
            args.append(String(describing: value))
        }
    }
}

/// Translate a German text into the current app language (German text is the key; English comes from `L10n.en`).
func tr(_ key: LKey) -> String {
    let template: String = Lang.shared.isEnglish ? (L10n.en[key.format] ?? key.format) : key.format
    if key.args.isEmpty { return template }
    var result = ""
    var remaining = key.args[...]
    var rest = Substring(template)
    while let range = rest.range(of: "%@") {
        result += rest[rest.startIndex..<range.lowerBound]
        if let arg = remaining.first { result += arg; remaining = remaining.dropFirst() }
        rest = rest[range.upperBound...]
    }
    result += rest
    return result
}
