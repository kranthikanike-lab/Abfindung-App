import Foundation

/// Explanation shown behind the "i" button of every tab.
enum TabInfo {
    static func title(_ tab: AppTab) -> String {
        switch tab {
        case .inputs: return tr("Eingaben")
        case .optimization: return tr("Steuer-Optimierung")
        case .results: return tr("Ergebnis")
        case .runway: return tr("Reichweite")
        case .crossover: return tr("Gehalts-Switch")
        }
    }

    static func text(_ tab: AppTab) -> String {
        switch tab {
        case .inputs: return tr("**Hier beschreiben Sie Ihre Ausgangslage.**\n\nGehalt, Start des Austritts, Kündigungsfrist, Abfindung und Familienmerkmale bestimmen die Steuer auf die Abfindung. Die **Sprinter-Option** vergleicht, was ein früherer Austritt gegenüber dem Absitzen der Kündigungsfrist bringt.\n\nDie wichtigsten Ergebnisse sehen Sie sofort in der Leiste unten, Details im Tab „Ergebnis“.")
        case .optimization: return tr("**Hebel, um die Steuer auf die Abfindung zu senken.**\n\nbAV-Einzahlung, Rentenausgleich an die DRV (V0210), Rürup und gewerblicher PV-IAB. Jeder Regler zeigt die Ersparnis und welcher Teil sofort und welcher erst mit der Steuererklärung im Oktober 2028 wirkt.\n\nSchalten Sie die Optimierung oben ein. Das ist eine Pro-Funktion.")
        case .results: return tr("**Was am Ende von der Abfindung bleibt.**\n\n„Sofort-Netto“ ist die Auszahlung nach dem Lohnsteuer-Einbehalt. „Optimal-Netto“ ist das Ergebnis nach der Steuererklärung (Fünftelregelung). Dazu kommen der Kontostand Ende 2028, Diagramme und die drei Rechentabellen.")
        case .runway: return tr("**Wie lange reicht das Geld ohne neuen Job?**\n\nVergleicht „Frist absitzen“ (Standard) mit „früher gehen“ (Sprinter): Gehalt, Ruhenszeit, ALG 1, Krankenversicherung und Ihre Ausgaben. Die Diagramme zeigen den Zeitstrahl und den Kontostand je Monat.\n\nSchalten Sie die Berechnung oben ein. Das ist eine Pro-Funktion.")
        case .crossover: return tr("**Neuer Job mit weniger Gehalt: ab wann ist der Vorsprung aus der Abfindung aufgebraucht?**\n\nDer Break-Even zeigt, wann das Plus aus der Abfindung durch das geringere Gehalt aufgebraucht ist, für Standard und Sprinter. Austritt, Ausgaben und ALG 1 kommen aus dem Tab „Reichweite“.\n\nSchalten Sie die Berechnung oben ein. Das ist eine Pro-Funktion.")
        }
    }
}
