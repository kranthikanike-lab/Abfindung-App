import Foundation

/// Features of the paid "Pro" tier. Everything else is Basic.
enum Feature: String, CaseIterable, Identifiable {
    case taxOptimization, runway, jobSwitch, report

    var id: String { rawValue }

    var title: String {
        switch self {
        case .taxOptimization: return tr("Steuer-Optimierung")
        case .runway: return tr("Cash-Burn & Reichweite")
        case .jobSwitch: return tr("Gehalts-Switch / Break-Even")
        case .report: return tr("PDF-Report")
        }
    }

    var icon: String {
        switch self {
        case .taxOptimization: return "percent"
        case .runway: return "hourglass"
        case .jobSwitch: return "arrow.left.arrow.right"
        case .report: return "doc.richtext"
        }
    }

    var summary: String {
        switch self {
        case .taxOptimization:
            return tr("Prüfen Sie, wie viel Steuer Sie mit Vorsorge-Hebeln rund um die Abfindung sparen können – inklusive Aufteilung der Finanzamt-Erstattung.")
        case .runway:
            return tr("Wie lange reicht Ihr Geld ohne neuen Job? Vergleich zwischen Frist absitzen und Sprinter-Austritt, inklusive ALG 1, Ruhenszeit und Krankenversicherung.")
        case .jobSwitch:
            return tr("Nehmen Sie einen neuen Job mit weniger Gehalt an? Sehen Sie, ab wann sich die Abfindung „aufgebraucht“ hat – Standard gegen Sprinter.")
        case .report:
            return tr("Exportieren Sie Ihre Berechnung als PDF zum Speichern oder Teilen.")
        }
    }

    var bullets: [String] {
        switch self {
        case .taxOptimization:
            return [tr("bAV-Einzahlung (§ 3 Nr. 63 EStG)"),
                    tr("AG-Direktzahlung an die DRV (V0210) mit Rentenpunkte-Rechner"),
                    tr("Rürup / Basisrente mit Sweet-Spot"),
                    tr("Gewerblicher PV-IAB (§ 7g EStG)"),
                    tr("Ersparnis je Hebel und Zusammensetzung der Erstattung")]
        case .runway:
            return [tr("Reichweite in Monaten und Enddatum"),
                    tr("Lebensphasen: Gehalt, Ruhenszeit, ALG 1, Privatiers"),
                    tr("Konto-Verlauf mit Finanzamt-Erstattung"),
                    tr("Minijob, Realzins, GKV-Optionen")]
        case .jobSwitch:
            return [tr("Monatliche Netto-Einbuße alt gegen neu"),
                    tr("Break-Even-Datum für Standard und Sprinter"),
                    tr("Puffer bei Job-Start und Gehaltswachstum")]
        case .report:
            return [tr("Alle Ergebnisse auf einer PDF-Seite")]
        }
    }

    /// Static example shown on the locked screen.
    var example: String {
        switch self {
        case .taxOptimization: return tr("Beispiel: Mit bAV und Rürup steigt die Finanzamt-Erstattung von rund 11.000 € auf über 48.000 € – Beträge hängen von Ihren Eingaben ab.")
        case .runway: return tr("Beispiel: Reichweite Standard 48 Monate, Sprinter 52 Monate – inklusive Hinweis, falls bis zur Erstattung im Oktober 2028 eine Lücke entsteht.")
        case .jobSwitch: return tr("Beispiel: Bei 1.500 € weniger Netto im Monat ist der Vorsprung aus der Abfindung nach rund 9 Jahren aufgebraucht.")
        case .report: return tr("Beispiel: Eine Seite mit Abfindung, Abzügen, Netto, Erstattung und Kontostand.")
        }
    }
}

enum Entitlements {
    /// While true, Pro can be switched on and off from the app menu for testing.
    /// To be replaced by the App Store in-app purchase before release.
    static let testMode = true
}
