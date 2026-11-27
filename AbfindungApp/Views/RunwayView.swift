import SwiftUI

struct RunwayProContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var m = model
        let r = model.results
        ScrollView {
            VStack(spacing: 10) {
                Card(title: tr("🧭 C. Cash-Burn & Reichweite (Überleben ohne Job)"),
                     subtitle: tr("Austrittsmonat und Gehalt kommen aus „Eingaben“ (Sprinter: \(r.salMonthsSpr)M | Standard: \(r.salMonthsStd)M Gehalt).")) {
                    Toggle(tr("Reichweite berechnen"), isOn: $m.inputs.runwayEnabled).font(.subheadline.weight(.semibold))
                    if !model.inputs.runwayEnabled {
                        Hint(tr("Einschalten, um Reichweite, Lebensphasen und Konto-Verlauf zu berechnen."))
                    }
                    if model.inputs.runwayEnabled {
                    AmountSlider(title: tr("Monatl. Netto-Ausgaben (ohne GKV, €)"), value: $m.inputs.runwayExpenses,
                                 range: 500...10_000, step: 100, hint: tr("Private Lebenshaltungskosten"))
                    StepperField(title: tr("Gesamter ALG-1 Anspruch (Monate)"), value: $m.inputs.runwayAlg1Months.asDouble,
                                 range: 0...24, step: 1,
                                 display: { v in tr("\(Int(v)) Mon.") },
                                 hint: tr("Sprinter: \(r.runwaySpr?.algMonths ?? 0)M (inkl. Sperrzeit) | Std: \(r.runwayStd?.algMonths ?? 0)M"))
                    AmountSlider(title: tr("Sofort-Abfluss 2027 (€)"), value: $m.inputs.runwayUpfrontSpend,
                                 range: 0...200_000, step: 5_000, hint: tr("Einmalausgabe / Tilgung / Rücklage"))
                    VStack(alignment: .leading, spacing: 4) {
                        FieldLabel(title: tr("GKV-Beitrag nach ALG 1"), info: Info.gkvNachAlg)
                        Picker("GKV", selection: $m.inputs.runwayGkvMode) {
                            ForEach(GkvMode.allCases) { Text($0.shortLabel).tag($0) }
                        }.pickerStyle(.segmented)
                        switch model.inputs.runwayGkvMode {
                        case .min: Hint(tr("~\(Fmt.eur(r.ctx?.gkvMinMonat ?? 0))/Mo (Mindestbeitrag)"))
                        case .fam: Hint(tr("0 €/Mo – über Partner/in mitversichert"))
                        case .custom:
                            AmountSlider(title: tr("Individueller GKV-Beitrag"), value: $m.inputs.runwayCustomGkv,
                                         range: 0...1_500, step: 10, suffix: "€/Mo")
                        }
                    }
                    StepperField(title: tr("Real-Zins / Inflation p.a. (%)"), value: $m.inputs.runwayRealReturn,
                                 range: -5...8, step: 0.5, info: Info.realReturn, decimals: 1, suffix: "%",
                                 hint: tr("Rendite nach Steuer minus Inflation"))
                    AmountSlider(title: tr("Minijob nach Austritt (€/Mo)"), value: $m.inputs.runwayMinijob,
                                 range: 0...556, step: 10, info: Info.minijob,
                                 hint: model.inputs.runwayMinijob > 0
                                ? tr("Während ALG 1: +\(Fmt.eur(min(165, model.inputs.runwayMinijob)))/Mo frei | Nach ALG 1: +\(Fmt.eur(model.inputs.runwayMinijob))/Mo voll")
                                : tr("Steuer- & GKV-frei (während ALG 1 max. 165 € frei)"))
                    Toggle(tr("Netto-Gehalt minus Ausgaben ansparen (Gehalts-Überschuss 2027)"), isOn: $m.inputs.runwayIncludeSalarySavings).font(.subheadline)
                    Toggle(tr("Rürup in Reichweite auf >100 % Cash-Plus begrenzen"), isOn: $m.inputs.runwayCapRuerupSweetSpot).font(.subheadline)
                    }
                }

                if let std = r.runwayStd, let spr = r.runwaySpr {
                    let delta = spr.exhaustedMonth - std.exhaustedMonth
                    KPIGrid {
                        KPITile(label: tr("Reichweite Standard (Frist)"),
                                value: tr("\(std.exhaustedMonth) Mon. (\(Fmt.decimal(Double(std.exhaustedMonth) / 12)) J.)"),
                                sub: tr("Bis \(monthLabel(std.exhaustedMonth))"))
                        KPITile(label: tr("Reichweite Sprinter (Sofort)"),
                                value: tr("\(spr.exhaustedMonth) Mon. (\(Fmt.decimal(Double(spr.exhaustedMonth) / 12)) J.)"),
                                sub: tr("Bis \(monthLabel(spr.exhaustedMonth))"), color: Theme.success)
                        KPITile(label: tr("Strategie-Vergleich (Sprinter vs. Std)"),
                                value: tr("\(delta >= 0 ? "+ " : "− ")\(abs(delta)) Mon."),
                                sub: delta >= 0 ? tr("Sprinter hält länger durch") : tr("Standard hält länger durch"),
                                color: delta >= 0 ? Theme.success : Theme.warning)
                        KPITile(label: tr("Okt. 2028 FA-Erstattung (Sprinter)"), value: Fmt.signedEur(spr.faRefundOct2028),
                                sub: spr.bridgeDeficitMax > 0
                                ? tr("Brücke ab \(monthLabel(spr.firstDeficitM ?? 0)): \(Fmt.eur(spr.bridgeDeficitMax))")
                                : tr("Zwischenfinanzierung: Keine"), color: Theme.accent)
                    }

                    if spr.bridgeDeficitMax > 0 {
                        Banner(text: tr("⚠️ **Okt.-2028 Brücke nötig:** Vor Eintreffen der Finanzamt-Erstattung (\(Fmt.eur(spr.faRefundOct2028))) entsteht ab **\(monthLabel(spr.firstDeficitM ?? 0))** ein kurzfristiger Liquiditätsbedarf von **\(Fmt.eur(spr.bridgeDeficitMax))**."), color: Theme.warning)
                    }

                    Card(title: tr("Lebensphasen-Zeitstrahl"),
                         subtitle: tr("Start: \(monthLabel(r.ctx?.preMonths ?? 0)) – der Monat aus „Start Frist / Sprinter-Austritt“.")) {
                        PhaseChart(std: std, spr: spr, startIndex: r.ctx?.preMonths ?? 0)
                    }
                    Card(title: tr("Konto-Verlauf (€)"),
                         subtitle: tr("Blau: Stand, den beide haben. Grün: Sprinter liegt vorn. Orange: Standard liegt vorn. Ein Punkt zeigt, wo das Geld aufgebraucht ist.")) {
                        RunwayBalanceChart(std: std, spr: spr)
                    }
                }
            }
            .padding(.horizontal, Theme.pageMargin)
            .padding(.vertical, 12)
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
        .navigationTitle(tr("Reichweite"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { AppToolbar(tab: .runway) }
        .themedBars()
    }
}

struct CrossoverProContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var m = model
        let r = model.results
        ScrollView {
            VStack(spacing: 10) {
                Card(title: tr("📉 D. Gehalts-Switch / Break-Even Rechner"),
                     subtitle: tr("Neuer Job mit weniger Gehalt. Austritt, Ausgaben, ALG 1, GKV & Realzins kommen aus „Reichweite“.")) {
                    Toggle(tr("Gehalts-Switch berechnen"), isOn: $m.inputs.crossoverEnabled).font(.subheadline.weight(.semibold))
                    if !model.inputs.crossoverEnabled {
                        Hint(tr("Einschalten, um Break-Even und Vermögens-Vorsprung zu berechnen."))
                    }
                    if model.inputs.crossoverEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        AmountSlider(title: tr("Neues Bruttogehalt (€)"), value: $m.inputs.crossoverNewGross,
                                     range: model.inputs.crossoverPerYear ? 0.0...180_000.0 : 0.0...15_000.0,
                                     step: model.inputs.crossoverPerYear ? 1_000 : 100,
                                     info: Info.crossoverSalary,
                                     hint: tr("Monatl. Netto-Einbuße: \(Fmt.eur(r.crossMonthlyLoss)) / Mo"))
                        Picker(tr("Zeitraum"), selection: Binding(
                            get: { model.inputs.crossoverPerYear },
                            set: { perYear in
                                // keep the same salary when switching between monthly and yearly
                                if perYear != model.inputs.crossoverPerYear {
                                    let v = model.inputs.crossoverNewGross
                                    model.inputs.crossoverNewGross = (perYear ? v * 12 : v / 12).rounded()
                                    model.inputs.crossoverPerYear = perYear
                                }
                            })) {
                            Text(tr("/ Monat")).tag(false)
                            Text(tr("/ Jahr")).tag(true)
                        }.pickerStyle(.segmented)
                    }
                    StepperField(title: tr("Job-Start (Monate nach Austritt)"), value: $m.inputs.crossoverDelayMonths.asDouble,
                                 range: 0...36, step: 1, info: Info.crossoverDelay,
                                 display: { v in tr("\(Int(v)) Mon.") },
                                 hint: model.inputs.crossoverDelayMonths == 0 ? tr("0 Mon. = Direkter Wechsel ohne Lücke")
                                      : tr("Job-Start \(monthLabel((r.crossStd?.jobStartM ?? 0))) (Standard)"))
                    StepperField(title: tr("Gehaltswachstum p.a. (Alt & Neu %)"), value: $m.inputs.crossoverGrowth,
                                 range: 0...10, step: 0.5, info: Info.crossoverGrowth, decimals: 1, suffix: "%",
                                 hint: tr("Symmetrisches Wachstum p.a."))
                    }
                }

                if let std = r.crossStd, let spr = r.crossSpr {
                    let beDate: (CrossoverResult) -> String = {
                        $0.breakevenMonthFromJan27.map(monthLabel) ?? tr("> 30 Jahre (Nie)")
                    }
                    let beDur: (CrossoverResult) -> String = {
                        $0.breakevenMonthsInNewJob.map { tr("\($0) Job-Mon. (\(Fmt.decimal(Double($0) / 12)) J.)") }
                            ?? tr("Gehaltslücke minimal / dauerhaft im Plus")
                    }
                    KPIGrid {
                        KPITile(label: tr("Monatl. Netto-Einbuße (Alt − Neu)"), value: "\(Fmt.eur(r.crossMonthlyLoss)) / Mo",
                                sub: tr("Alt: \(Fmt.eur(std.baseOldNet)) vs. Neu: \(Fmt.eur(std.baseNewNet))"), color: Theme.warning)
                        KPITile(label: tr("Break-Even Standard (Frist)"), value: beDate(std), sub: beDur(std))
                        KPITile(label: tr("Break-Even Sprinter (Sofort)"), value: beDate(spr), sub: beDur(spr), color: Theme.success)
                        if let a = std.breakevenMonthFromJan27, let b = spr.breakevenMonthFromJan27 {
                            let d = b - a
                            KPITile(label: tr("Strategie-Vorteil (Sprinter vs. Std)"), value: tr("\(d >= 0 ? "+ " : "− ")\(abs(d)) Mon."),
                                    sub: tr("Puffer Sprinter: \(Fmt.eur(spr.cushionAtJobStart)) | Std: \(Fmt.eur(std.cushionAtJobStart))"),
                                    color: d >= 0 ? Theme.success : Theme.warning)
                        } else {
                            KPITile(label: tr("Strategie-Vorteil (Sprinter vs. Std)"),
                                    value: spr.cushionAtJobStart >= std.cushionAtJobStart ? tr("+ Puffer-Plus") : tr("Vergleich"),
                                    sub: tr("Puffer Sprinter: \(Fmt.eur(spr.cushionAtJobStart)) | Std: \(Fmt.eur(std.cushionAtJobStart))"),
                                    color: Theme.accent)
                        }
                    }
                    Card(title: tr("Vermögens-Vorsprung vs. Verbleib im alten Job (€)"),
                         subtitle: tr("Standard vs. Sprinter bis Break-Even (0 €). Grün: Sprinter liegt vorn, Orange: Standard liegt vorn.")) {
                        ComparisonAreaChart(spr: spr.advSeries, std: std.advSeries,
                                            sprName: tr("Sprinter Vorsprung"), stdName: tr("Standard Vorsprung"),
                                            zeroColor: Theme.danger, zeroDashed: true,
                                            zeroLabel: "Break-Even (0 €)", height: 260)
                    }
                }
            }
            .padding(.horizontal, Theme.pageMargin)
            .padding(.vertical, 12)
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
        .navigationTitle(tr("Gehalts-Switch"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { AppToolbar(tab: .crossover) }
        .themedBars()
    }
}
