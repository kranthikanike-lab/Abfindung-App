import SwiftUI

struct RunwayProContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var m = model
        let r = model.results
        ScrollView {
            VStack(spacing: 14) {
                Card(title: "🧭 C. Cash-Burn & Reichweite (Überleben ohne Job)",
                     subtitle: "Austrittsmonat und Gehalt kommen aus „Eingaben“ (Sprinter: \(r.salMonthsSpr)M | Standard: \(r.salMonthsStd)M Gehalt).") {
                    Toggle("Reichweite berechnen", isOn: $m.inputs.runwayEnabled).font(.subheadline.weight(.semibold))
                    if !model.inputs.runwayEnabled {
                        Hint("Einschalten, um Reichweite, Lebensphasen und Konto-Verlauf zu berechnen.")
                    }
                    if model.inputs.runwayEnabled {
                    NumberField(title: "Monatl. Netto-Ausgaben (ohne GKV, €)", value: $m.inputs.runwayExpenses,
                                hint: "Private Lebenshaltungskosten")
                    IntField(title: "Gesamter ALG-1 Anspruch (Monate)", value: $m.inputs.runwayAlg1Months,
                             hint: "Sprinter: \(r.runwaySpr?.algMonths ?? 0)M (inkl. Sperrzeit) | Std: \(r.runwayStd?.algMonths ?? 0)M")
                    NumberField(title: "Sofort-Abfluss 2027 (€)", value: $m.inputs.runwayUpfrontSpend,
                                hint: "Einmalausgabe / Tilgung / Rücklage")
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(title: "GKV-Status nach ALG 1", info: Info.runwayGkv)
                        Picker("GKV", selection: $m.inputs.runwayGkvMode) {
                            ForEach(GkvMode.allCases) { Text($0.label).tag($0) }
                        }.pickerStyle(.menu)
                        if model.inputs.runwayGkvMode == .custom {
                            NumberField(title: "Individueller GKV-Beitrag", value: $m.inputs.runwayCustomGkv, suffix: "€/Mo")
                        }
                    }
                    NumberField(title: "Real-Zins / Inflation p.a. (%)", value: $m.inputs.runwayRealReturn,
                                info: Info.realReturn, hint: "Rendite nach Steuer minus Inflation")
                    NumberField(title: "Minijob nach Austritt (€/Mo)", value: $m.inputs.runwayMinijob, info: Info.minijob,
                                hint: model.inputs.runwayMinijob > 0
                                ? "Während ALG 1: +\(Fmt.eur(min(165, model.inputs.runwayMinijob)))/Mo frei | Nach ALG 1: +\(Fmt.eur(model.inputs.runwayMinijob))/Mo voll"
                                : "Steuer- & GKV-frei (während ALG 1 max. 165 € frei)")
                    Toggle("Netto-Gehalt minus Ausgaben ansparen (Gehalts-Überschuss 2027)", isOn: $m.inputs.runwayIncludeSalarySavings).font(.subheadline)
                    Toggle("Rürup in Reichweite auf >100 % Cash-Plus begrenzen", isOn: $m.inputs.runwayCapRuerupSweetSpot).font(.subheadline)
                    }
                }

                if let std = r.runwayStd, let spr = r.runwaySpr {
                    let delta = spr.exhaustedMonth - std.exhaustedMonth
                    KPIGrid {
                        KPITile(label: "Reichweite Standard (Frist)",
                                value: "\(std.exhaustedMonth) Mon. (\(String(format: "%.1f", locale: Locale(identifier: "de_DE"), Double(std.exhaustedMonth) / 12)) J.)",
                                sub: "Bis \(monthLabel(std.exhaustedMonth))")
                        KPITile(label: "Reichweite Sprinter (Sofort)",
                                value: "\(spr.exhaustedMonth) Mon. (\(String(format: "%.1f", locale: Locale(identifier: "de_DE"), Double(spr.exhaustedMonth) / 12)) J.)",
                                sub: "Bis \(monthLabel(spr.exhaustedMonth))", color: Theme.success)
                        KPITile(label: "Strategie-Vergleich (Sprinter vs. Std)",
                                value: "\(delta >= 0 ? "+ " : "− ")\(abs(delta)) Mon.",
                                sub: delta >= 0 ? "Sprinter hält länger durch" : "Standard hält länger durch",
                                color: delta >= 0 ? Theme.success : Theme.warning)
                        KPITile(label: "Okt. 2028 FA-Erstattung (Sprinter)", value: Fmt.signedEur(spr.faRefundOct2028),
                                sub: spr.bridgeDeficitMax > 0
                                ? "Brücke ab \(monthLabel(spr.firstDeficitM ?? 0)): \(Fmt.eur(spr.bridgeDeficitMax))"
                                : "Zwischenfinanzierung: Keine", color: Theme.accent)
                    }

                    if spr.bridgeDeficitMax > 0 {
                        Banner(text: "⚠️ **Okt.-2028 Brücke nötig:** Vor Eintreffen der Finanzamt-Erstattung (\(Fmt.eur(spr.faRefundOct2028))) entsteht ab **\(monthLabel(spr.firstDeficitM ?? 0))** ein kurzfristiger Liquiditätsbedarf von **\(Fmt.eur(spr.bridgeDeficitMax))**.", color: Theme.warning)
                    }

                    Card(title: "Lebensphasen-Zeitstrahl",
                         subtitle: "Start: \(monthLabel(r.ctx?.preMonths ?? 0)) – der Monat aus „Start Frist / Sprinter-Austritt“.") {
                        PhaseChart(std: std, spr: spr, startIndex: r.ctx?.preMonths ?? 0)
                    }
                    Card(title: "Konto-Verlauf (€)",
                         subtitle: "Blau: Stand, den beide haben. Grün: Sprinter liegt vorn. Orange: Standard liegt vorn. Ein Punkt zeigt, wo das Geld aufgebraucht ist.") {
                        RunwayBalanceChart(std: std, spr: spr)
                    }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.pageBackground)
    }
}

struct RunwayView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Group {
            if model.isPro { RunwayProContent() } else { ProLockedView(feature: .runway) }
        }
        .navigationTitle("Reichweite")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { AppToolbar() }
        .themedBars()
    }
}

struct CrossoverProContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var m = model
        let r = model.results
        ScrollView {
            VStack(spacing: 14) {
                Card(title: "📉 D. Gehalts-Switch / Break-Even Rechner",
                     subtitle: "Neuer Job mit weniger Gehalt. Austritt, Ausgaben, ALG 1, GKV & Realzins kommen aus „Reichweite“.") {
                    Toggle("Gehalts-Switch berechnen", isOn: $m.inputs.crossoverEnabled).font(.subheadline.weight(.semibold))
                    if !model.inputs.crossoverEnabled {
                        Hint("Einschalten, um Break-Even und Vermögens-Vorsprung zu berechnen.")
                    }
                    if model.inputs.crossoverEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        NumberField(title: "Neues Bruttogehalt (€)", value: $m.inputs.crossoverNewGross, info: Info.crossoverSalary,
                                    hint: "Monatl. Netto-Einbuße: \(Fmt.eur(r.crossMonthlyLoss)) / Mo")
                        Picker("Zeitraum", selection: $m.inputs.crossoverPerYear) {
                            Text("/ Monat").tag(false)
                            Text("/ Jahr").tag(true)
                        }.pickerStyle(.segmented)
                    }
                    IntField(title: "Job-Start (Monate nach Austritt)", value: $m.inputs.crossoverDelayMonths,
                             info: Info.crossoverDelay,
                             hint: model.inputs.crossoverDelayMonths == 0 ? "0 Mon. = Direkter Wechsel ohne Lücke"
                                   : "Job-Start \(monthLabel((r.crossStd?.jobStartM ?? 0))) (Standard)")
                    NumberField(title: "Gehaltswachstum p.a. (Alt & Neu %)", value: $m.inputs.crossoverGrowth,
                                info: Info.crossoverGrowth, hint: "Symmetrisches Wachstum p.a.")
                    }
                }

                if let std = r.crossStd, let spr = r.crossSpr {
                    let beDate: (CrossoverResult) -> String = {
                        $0.breakevenMonthFromJan27.map(monthLabel) ?? "> 30 Jahre (Nie)"
                    }
                    let beDur: (CrossoverResult) -> String = {
                        $0.breakevenMonthsInNewJob.map { "\($0) Job-Mon. (\(String(format: "%.1f", locale: Locale(identifier: "de_DE"), Double($0) / 12)) J.)" }
                            ?? "Gehaltslücke minimal / dauerhaft im Plus"
                    }
                    KPIGrid {
                        KPITile(label: "Monatl. Netto-Einbuße (Alt − Neu)", value: "\(Fmt.eur(r.crossMonthlyLoss)) / Mo",
                                sub: "Alt: \(Fmt.eur(std.baseOldNet)) vs. Neu: \(Fmt.eur(std.baseNewNet))", color: Theme.warning)
                        KPITile(label: "Break-Even Standard (Frist)", value: beDate(std), sub: beDur(std))
                        KPITile(label: "Break-Even Sprinter (Sofort)", value: beDate(spr), sub: beDur(spr), color: Theme.success)
                        if let a = std.breakevenMonthFromJan27, let b = spr.breakevenMonthFromJan27 {
                            let d = b - a
                            KPITile(label: "Strategie-Vorteil (Sprinter vs. Std)", value: "\(d >= 0 ? "+ " : "− ")\(abs(d)) Mon.",
                                    sub: "Puffer Sprinter: \(Fmt.eur(spr.cushionAtJobStart)) | Std: \(Fmt.eur(std.cushionAtJobStart))",
                                    color: d >= 0 ? Theme.success : Theme.warning)
                        } else {
                            KPITile(label: "Strategie-Vorteil (Sprinter vs. Std)",
                                    value: spr.cushionAtJobStart >= std.cushionAtJobStart ? "+ Puffer-Plus" : "Vergleich",
                                    sub: "Puffer Sprinter: \(Fmt.eur(spr.cushionAtJobStart)) | Std: \(Fmt.eur(std.cushionAtJobStart))",
                                    color: Theme.accent)
                        }
                    }
                    Card(title: "Vermögens-Vorsprung vs. Verbleib im alten Job (€)",
                         subtitle: "Standard vs. Sprinter bis Break-Even (0 €). Grün: Sprinter liegt vorn, Orange: Standard liegt vorn.") {
                        ComparisonAreaChart(spr: spr.advSeries, std: std.advSeries,
                                            sprName: "Sprinter Vorsprung", stdName: "Standard Vorsprung",
                                            zeroColor: Theme.danger, zeroDashed: true,
                                            zeroLabel: "Break-Even (0 €)", height: 260)
                    }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.pageBackground)
    }
}

struct CrossoverView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Group {
            if model.isPro { CrossoverProContent() } else { ProLockedView(feature: .jobSwitch) }
        }
        .navigationTitle("Gehalts-Switch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { AppToolbar() }
        .themedBars()
    }
}
