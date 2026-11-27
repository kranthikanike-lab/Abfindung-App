import SwiftUI

/// Tab "Steuer": the Pro levers around the Abfindung (bAV, DRV V0210, Rürup, PV-IAB).
struct OptimizationView: View {
    @Environment(AppModel.self) private var model
    @State private var showDrv = false

    var body: some View {
        Group {
            if model.isPro { content } else { ProLockedView(feature: .taxOptimization) }
        }
        .navigationTitle(tr("Steuer-Optimierung"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { AppToolbar(tab: .optimization) }
        .themedBars()
        .safeAreaInset(edge: .bottom) { StickyKPIBar() }
        .sheet(isPresented: $showDrv) { DrvDeficitSheet() }
    }

    private var content: some View {
        @Bindable var m = model
        let r = model.results
        return ScrollView {
            VStack(spacing: 14) {
                optimizationCard(m: $m, r: r)
            }
            .padding(.horizontal, Theme.pageMargin)
            .padding(.vertical, 12)
            .padding(.bottom, 70)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.pageBackground)
    }

    @ViewBuilder
    private func optimizationCard(m: Bindable<AppModel>, r: Results) -> some View {
        let on = model.inputs.optEnabled
        let badge = on ? tr("Aktiv (\(Fmt.eur(r.totalOptVolume)))") : tr("Minimiert (0 €)")
        SectionToggle(title: tr("🎯 B. Steuer-Optimierung (bAV, DRV V0210, Rürup, PV-IAB)"), badge: badge,
                      isOn: Binding(get: { model.inputs.optEnabled }, set: { model.setOptEnabled($0) })) {
            SliderCard(title: tr("1. bAV-Einzahlung (§ 3 Nr. 63 EStG)"), info: Info.bav,
                       valueText: Fmt.eur(r.bav),
                       pill: r.bavSaving.amount > 0 ? tr("Sofort-Ersparnis: \(Fmt.eur(r.bavSaving.savings)) (\(Fmt.pct(r.bavSaving.percent)))") : nil,
                       value: m.inputs.bav, range: 0...Const.maxBav, step: 500,
                       hint: tr("Max. 50.976 € (42.480 € Vervielfältiger + 8.496 € 2027-Rahmen, Annahme: 0 € laufende bAV)."),
                       explainLabel: r.bavSaving.amount > 0 ? tr("🛡️ Sofort-Steuerersparnis (2027 Lohnsteuer-Abzug):") : nil,
                       explainValue: "\(Fmt.eur(r.bavSaving.savings)) (\(Fmt.pct(r.bavSaving.percent)))")

            SliderCard(title: tr("2. AG-Direktzahlung DRV (§ 187a / V0210)"), info: Info.drv,
                       valueText: Fmt.eur(r.drvRaw),
                       pill: r.drvSaving.amount > 0 ? tr("Ersparnis: \(Fmt.eur(r.drvSaving.savings)) (\(Fmt.pct(r.drvSaving.percent)))") : nil,
                       value: m.inputs.drv, range: 0...model.inputs.drvMax, step: 500,
                       hint: tr("50 % steuerfrei (§ 3 Nr. 28 EStG: \(Fmt.eur(r.drvTaxFree))) ohne Rürup-Cap-Kürzung; 50 % Fünftelregelung."),
                       extraAction: (tr("🎯 Defizit berechnen"), { showDrv = true }),
                       explainLabel: r.drvSaving.amount > 0 ? tr("💡 Gesamt-Ersparnis (50% Sofort + 50% Fünftel):") : nil,
                       explainValue: "\(Fmt.eur(r.drvSaving.savings)) (\(Fmt.pct(r.drvSaving.percent)))")

            SliderCard(title: tr("3. Rürup / Basisrente (§ 10 Abs. 1 Nr. 2 EStG)"), info: Info.ruerup,
                       valueText: Fmt.eur(r.ruerup),
                       pill: r.ruerupSaving.amount > 0 ? tr("FA-Erstattung: \(Fmt.eur(r.ruerupSaving.savings)) (\(Fmt.pct(r.ruerupSaving.percent)))") : nil,
                       value: m.inputs.ruerup, range: 0...max(1, jsRound(r.maxRuerup)), step: 250,
                       hint: tr("Max. Cap 2027: \(Fmt.eur(r.maxRuerup)) (⚠️ Kapital dauerhaft gebunden)"),
                       sweetTitle: tr("🎯 Cash-Plus Sweet-Spot (>100%): \(Fmt.eur(r.ruerupSweetSpot))"),
                       sweetAction: { model.applyRuerupSweetSpot() },
                       explainLabel: r.ruerupSaving.amount > 0 ? tr("💡 Steuer-Erstattung (Okt. 2028 FA):") : nil,
                       explainValue: "\(Fmt.eur(r.ruerupSaving.savings)) (\(Fmt.pct(r.ruerupSaving.percent)))")

            SliderCard(title: tr("4. Gewerbl. PV-IAB (§ 7g EStG — 50% Abzug)"), info: Info.iab,
                       valueText: tr("\(Fmt.eur(r.iabInvest)) (Abzug: \(Fmt.eur(r.iab)))"),
                       pill: r.iabSaving.amount > 0 ? tr("FA-Erstattung: \(Fmt.eur(r.iabSaving.savings)) (\(Fmt.pct(r.iabSaving.percent)))") : nil,
                       value: m.inputs.iabInvest, range: 0...400_000, step: 2000,
                       hint: tr("Kaufpreis bis 400.000 € → 50% IAB-Abzug in 2027"),
                       sweetTitle: tr("🎯 IAB Sweet-Spot: \(Fmt.eur(r.iabSweetInvest)) (Abzug: \(Fmt.eur(r.iabSweetAbzug)))"),
                       sweetAction: { model.applyIabSweetSpot() },
                       explainLabel: r.iabSaving.amount > 0 ? tr("💡 Steuer-Erstattung auf Kaufpreis (Okt. 2028):") : nil,
                       explainValue: "\(Fmt.eur(r.iabSaving.savings)) (\(Fmt.pct(r.iabSaving.percent)))")
        }
    }
}
