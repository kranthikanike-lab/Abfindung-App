import SwiftUI

private var monthNames: [String] { [tr("Januar"), tr("Februar"), tr("März"), tr("April"), tr("Mai"), tr("Juni"), tr("Juli"), tr("August"),
                          tr("September"), tr("Oktober"), tr("November"), tr("Dezember")] }
private var kinderOptions: [(Double, String)] { [
    (0, tr("0 Kinder")), (0.5, tr("0,5 (1 Kind geteilt)")), (1, tr("1,0 (1 Kind voll)")),
    (1.5, tr("1,5 Kinder")), (2, tr("2,0 Kinder")), (2.5, tr("2,5 Kinder")), (3, tr("3,0 Kinder"))
] }

struct InputsView: View {
    @Environment(AppModel.self) private var model
    @State private var showDrv = false

    var body: some View {
        @Bindable var m = model
        let r = model.results
        ScrollView {
            VStack(spacing: 14) {
                coreCard(m: $m, r: r)
                sprinterCard(m: $m, r: r)
                if model.isPro {
                    optimizationCard(m: $m, r: r)
                } else {
                    ProLockedCard(feature: .taxOptimization)
                }
            }
            .padding(.horizontal, Theme.pageMargin)
            .padding(.vertical, 12)
            .padding(.bottom, 70)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.pageBackground)
        .navigationTitle("Abfindungs-Optimizer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { AppToolbar() }
        .themedBars()
        .safeAreaInset(edge: .bottom) { StickyKPIBar() }
        .sheet(isPresented: $showDrv) { DrvDeficitSheet() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(tr("Fertig")) { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
    }

    // MARK: A. Basis

    @ViewBuilder
    private func coreCard(m: Bindable<AppModel>, r: Results) -> some View {
        Card(title: tr("A. Basis-Parameter & Einkommen 2027"),
             subtitle: tr("Annahme: Einmal-Auszahlung in einer Gehaltsabrechnung 2027 (§ 34 EStG Zusammenballung)")) {
            NumberField(title: tr("Reguläres Brutto-Monatsgehalt (€)"), value: m.inputs.altesMonatsgehalt,
                        info: Info.altesGehalt, hint: tr("Jahresbrutto: \(Fmt.eur(r.jahresBrutto))"))

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: tr("Start Frist / Sprinter-Austritt 2027"), info: Info.startMonth)
                Picker(tr("Startmonat"), selection: m.inputs.startMonth) {
                    ForEach(1...12, id: \.self) { n in
                        Text(tr("\(monthNames[n - 1]) 2027 (\(n - 1) Mon. Vor-Gehalt)")).tag(n)
                    }
                }
                .pickerStyle(.menu)
                Hint(tr("Sprinter: \(r.salMonthsSpr)M Gehalt | Standard: \(r.salMonthsStd)M Gehalt"))
            }

            IntField(title: tr("Kündigungsfrist (Monate)"), value: m.inputs.fristMonate, info: Info.frist,
                     hint: tr("Restlaufzeit ab Startmonat. Die Auszahlung wird immer in 2027 angenommen."))
            NumberField(title: tr("Basis-Abfindung (Brutto €)"), value: m.inputs.bruttoAbfindung,
                        info: Info.abfindung, hint: tr("Ohne Sprinter-Prämie"))
            NumberField(title: tr("Neues Gehalt 2027 (Brutto €)"), value: m.inputs.neuesGehalt,
                        info: Info.neuesGehalt, hint: tr("Nur das Gehalt NACH der Lücke / dem Austritt in 2027 eintragen."))
            NumberField(title: tr("Fiktives AG-Jahresgehalt (€)"), value: m.inputs.agFiktivGehalt,
                        info: Info.agFiktiv, hint: tr("Basis für Lohnsteuer-Einbehalt"))

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: tr("KV-Zusatzbeitrag (%) & Status"), info: Info.gkv)
                HStack {
                    TextField("2,5", value: m.inputs.zusatzbeitrag, format: .number)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(Theme.field, in: RoundedRectangle(cornerRadius: 10))
                        .frame(maxWidth: 110)
                    Picker("Status", selection: m.inputs.preExitGkvPflicht) {
                        Text(tr("Pflicht (§19)")).tag(true)
                        Text(tr("Freiwillig")).tag(false)
                    }.pickerStyle(.segmented)
                }
                Hint(tr("GKV-Höchstsatz: ~\(Fmt.eur(r.gkvHoechst))/Mo"))
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: tr("Kinder (Freibetrag)"), info: Info.kinder)
                Picker(tr("Kinder"), selection: Binding(get: { model.inputs.kinder }, set: { model.setKinder($0) })) {
                    ForEach(kinderOptions, id: \.0) { Text($0.1).tag($0.0) }
                }.pickerStyle(.menu)
                Hint(tr("KFB: \(Fmt.eur(r.kfb)) vs. KG: \(Fmt.eur(r.kg))"))
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: tr("Kirchensteuer"), info: Info.kirchensteuer)
                Picker(tr("Kirchensteuer"), selection: m.inputs.kirchensteuer) {
                    Text(tr("Keine")).tag(0.0)
                    Text("8 % (BY, BW)").tag(0.08)
                    Text(tr("9 % (übrige)")).tag(0.09)
                }.pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: tr("Steuertarif 2027"), info: Info.tarif)
                Picker(tr("Tarif"), selection: m.inputs.splitting) {
                    Text(tr("Grundtarif")).tag(false)
                    Text(tr("Splitting")).tag(true)
                }.pickerStyle(.segmented)
            }

            if model.inputs.splitting {
                NumberField(title: tr("Brutto-Gehalt Partner/in 2027 (€)"), value: m.inputs.partnerGehalt,
                            hint: r.splitting.map { tr("Splitting-Vorteil bis ca. \(Fmt.eur($0.maxPartnerGross)) Partner-Brutto") })
                if let s = r.splitting {
                    if s.advantage >= 0 {
                        Banner(text: tr("✅ **Splitting-Vorteil (+ \(Fmt.eur(s.advantage))):** Zusammenveranlagung ist bis ca. **\(Fmt.eur(s.maxPartnerGross))** Partner-Brutto günstiger als Einzelveranlagung."), color: Theme.success)
                    } else {
                        Banner(text: tr("⚠️ **Fünftel-Falle (− \(Fmt.eur(abs(s.advantage)))):** Zusammenveranlagung kostet hier extra! Einzelveranlagung (Grundtarif) prüfen (Grenze: ~\(Fmt.eur(s.maxPartnerGross)))."), color: Theme.danger)
                    }
                }
            }
        }
    }

    // MARK: Sprinter

    @ViewBuilder
    private func sprinterCard(m: Bindable<AppModel>, r: Results) -> some View {
        let on = model.inputs.isTurbo
        let badge = on ? tr("Aktiv (\(r.sprinterNetDiff >= 0 ? "+" : "−")\(Fmt.eur(abs(r.sprinterNetDiff))) Netto-Bilanz)")
                       : tr("Inaktiv (Frist wird regulär abgesessen)")
        SectionToggle(title: tr("🚀 Vorzeitiger Austritt / Sprinter-Option"), badge: badge, isOn: m.inputs.isTurbo) {
            NumberField(title: tr("Sprinter-Faktor (pro Monat)"), value: m.inputs.turboFaktor, info: Info.sprinterFaktor,
                        hint: tr("Brutto-Prämie: + \(Fmt.eur(r.sprinterBruttoPraemie))"))
            NumberField(title: tr("Anrechnungsanteil Ruhenszeit (%)"), value: m.inputs.ruhensAnteil, info: Info.ruhensAnteil,
                        hint: tr("Gesetzlich 25–60 %, 60 % = vorsichtig. Ruhenszeit: \(r.ruhensMonthsSprinter) Mon., Sperrzeit kürzt ALG 1 um \(r.sperrzeitMonths) Mon."))
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: tr("ALG 1 Satz (Auto aus Brutto & Kinder)"), info: Info.alg1)
                Picker("ALG 1", selection: m.inputs.alg1Satz) {
                    Text(tr("67 % (mit Kind)")).tag(0.67)
                    Text(tr("60 % (ohne Kind)")).tag(0.60)
                }.pickerStyle(.segmented)
                Hint(tr("ALG 1 Netto: ~\(Fmt.eur(r.alg1Monat))/Mo"))
            }
            Toggle(tr("ALG-1-Verlust einrechnen (Anspruch voll ausgeschöpft)"), isOn: m.inputs.includeAlg1Loss)
                .font(.subheadline)
            KPITile(label: tr("Isolierte Netto-Prämie"), value: "+ " + Fmt.eur(r.isolatedNettoPraemie),
                    sub: tr("Nach § 34 EStG Fünftelregelung"), color: Theme.success)

            let diff = r.sprinterNetDiff
            if diff >= 0 {
                Banner(text: tr("✅ **Sprinter-Vorteil (+ \(Fmt.eur(diff))):** Netto-Prämie (+ \(Fmt.eur(r.isolatedNettoPraemie))) & Steuer-Hebel (+ \(Fmt.eur(r.pureFuenftelAdvantage))) überkompensieren Gehaltsverlust & Abzüge."), color: Theme.success)
            } else {
                Banner(text: tr("⚠️ **Sprinter-Nachteil (− \(Fmt.eur(abs(diff)))):** Gehaltsverlust & Abzüge übersteigen Prämie & Steuer-Hebel."), color: Theme.danger)
            }
            SprinterDetails(r: r)
        }
    }

    // MARK: B. Optimierung

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
