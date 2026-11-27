import Foundation

enum GkvMode: String, Codable, CaseIterable, Identifiable {
    case min, fam, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .min: return tr("Freiwillig GKV Mindestbeitrag (~280 €/Mo)")
        case .fam: return tr("Familienversicherung Partner/in (0 €/Mo)")
        case .custom: return tr("Individuell (€/Mo)")
        }
    }
}

/// All user inputs (mirrors the form fields of the HTML calculator, incl. its defaults).
struct Inputs: Codable, Equatable {
    // A. Basis
    var altesMonatsgehalt = 7000.0
    var startMonth = 4
    var fristMonate = 5
    var bruttoAbfindung = 150_000.0
    var neuesGehalt = 0.0
    /// true: notional employer salary = 12 × monthly salary (default); false: use `agFiktivGehalt`.
    var agFiktivAuto = true
    var agFiktivGehalt = 84_000.0
    var zusatzbeitrag = 2.9
    var preExitGkvPflicht = true
    var kinder = 0.5
    /// Kirchensteuersatz as fraction: 0 (keine), 0.08 (BY, BW), 0.09 (übrige Länder).
    var kirchensteuer = 0.0
    var splitting = false
    var partnerGehalt = 45_000.0

    // Sprinter
    var isTurbo = false
    var turboFaktor = 1.5
    var alg1Satz = 0.67
    var includeAlg1Loss = false
    /// Anrechnungsanteil der Abfindung für die Ruhenszeit (§ 158 SGB III: 25–60 %). 60 % = vorsichtigster Wert.
    var ruhensAnteil = 60.0

    // B. Steuer-Optimierung
    var optEnabled = false
    var bav = 0.0
    var drv = 0.0
    var drvMax = 60_000.0
    var ruerup = 0.0
    var iabInvest = 0.0

    // C. Runway (Pro)
    var runwayEnabled = false
    var runwayExpenses = 3500.0
    var runwayAlg1Months = 12
    var runwayUpfrontSpend = 0.0
    var runwayGkvMode = GkvMode.min
    var runwayCustomGkv = 650.0
    var runwayRealReturn = 0.0
    var runwayMinijob = 0.0
    var runwayIncludeSalarySavings = true
    var runwayCapRuerupSweetSpot = true

    // D. Crossover (Pro)
    var crossoverEnabled = false
    var crossoverNewGross = 5500.0
    var crossoverPerYear = false
    var crossoverDelayMonths = 0
    var crossoverGrowth = 2.0

    var spl: Double { splitting ? 2 : 1 }
}

enum Preset { case sprinterSweet, runwayCheck, gehaltsSwitch, reset }
