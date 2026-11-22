# Abfindungs-Optimizer 2027 (iPhone)

Native SwiftUI port of `Reference/rechner_pro_v26_9.html` (Abfindungs-Optimizer 2027 PRO v26.9).
All tax logic (§ 32a Tarif, Fünftelregelung, Soli, Kinder-Günstigerprüfung, bAV/DRV/Rürup/PV-IAB,
Sprinter-Bilanz, Cash-Burn-Reichweite, Gehalts-Switch/Break-Even) is ported 1:1 into
`AbfindungApp/Core`, and the Chart.js charts are rebuilt with Swift Charts.

## Screens (iPhone, iOS 17+)
| Tab | Content |
|---|---|
| Eingaben | A. Basis-Parameter, Sprinter-Option, B. Steuer-Optimierung, sticky KPI-Leiste |
| Ergebnis | KPI-Kacheln, 3 Diagramme, Tabellen 1–3 |
| Reichweite | C. Cash-Burn & Reichweite |
| Switch | D. Gehalts-Switch / Break-Even |

Menü oben: Schnell-Szenarien, Hell/Dunkel/System, Rechengrößen & Recht 2027, Report als PDF teilen.
Eingaben werden automatisch gespeichert.

## Basic and Pro
| | Basic (free) | Pro (one-time purchase, planned) |
|---|---|---|
| Inputs A (Einkommen, Kinder, Splitting, Kirchensteuer) | ✅ | ✅ |
| Sprinter option incl. Bilanz | ✅ | ✅ |
| Results: KPIs, charts 1–2, Tables 1–3 | ✅ | ✅ |
| B. Steuer-Optimierung (bAV, DRV V0210, Rürup, PV-IAB) | locked | ✅ |
| C. Reichweite (Cash-Burn) | locked | ✅ |
| D. Gehalts-Switch / Break-Even | locked | ✅ |
| PDF report, quick scenarios | locked | ✅ |

Pro features never influence a Basic result, and unused features never appear in charts or tables.
In this version Pro is switched on/off from the ⋯ menu (`Entitlements.testMode`); the App Store purchase replaces that before release.

## Build (macOS + Xcode 15+)
```bash
brew install xcodegen
xcodegen generate        # creates AbfindungApp.xcodeproj from project.yml
open AbfindungApp.xcodeproj
```
Then pick your Team under *Signing & Capabilities* and run on an iPhone / simulator.

## Tests
`AbfindungAppTests/CalculatorTests.swift` compares the Swift results with values captured from the
original HTML in a headless browser (4 scenarios). GitHub Actions (`.github/workflows/ios.yml`) builds
and runs them on every push.

## Notes
- Calculations are an unverbindliche Modellrechnung, no tax advice.
- Tooltips ("?") open as sheets; the browser "Print/PDF" button became a PDF share action.
- The DRV slider maximum is `max(60.000 €, Nachkauf-Betrag)`; the HTML shrank it to the Nachkauf-Betrag.
