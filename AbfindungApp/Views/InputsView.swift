import SwiftUI

private let monthNames = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August",
                          "September", "Oktober", "November", "Dezember"]
private let kinderOptions: [(Double, String)] = [
    (0, "0 Kinder"), (0.5, "0,5 (1 Kind geteilt)"), (1, "1,0 (1 Kind voll)"),
    (1.5, "1,5 Kinder"), (2, "2,0 Kinder"), (2.5, "2,5 Kinder"), (3, "3,0 Kinder")
]

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
                optimizationCard(m: $m, r: r)
            }
            .padding()
            .padding(.bottom, 70)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Abfindungs-Optimizer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { AppToolbar() }
        .safeAreaInset(edge: .bottom) { StickyKPIBar() }
        .sheet(isPresented: $showDrv) { DrvDeficitSheet() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
    }

    // MARK: A. Basis

    @ViewBuilder
    private func coreCard(m: Bindable<AppModel>, r: Results) -> some View {
        Card(title: "A. Basis-Parameter & Einkommen 2027",
             subtitle: "Annahme: Einmal-Auszahlung in einer Gehaltsabrechnung 2027 (§ 34 EStG Zusammenballung)") {
            NumberField(title: "Reguläres Brutto-Monatsgehalt (€)", value: m.inputs.altesMonatsgehalt,
                        info: Info.altesGehalt, hint: "Jahresbrutto: \(Fmt.eur(r.jahresBrutto))")

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: "Start Frist / Sprinter-Austritt 2027", info: Info.startMonth)
                Picker("Startmonat", selection: m.inputs.startMonth) {
                    ForEach(1...12, id: \.self) { n in
                        Text("\(monthNames[n - 1]) 2027 (\(n - 1) Mon. Vor-Gehalt)").tag(n)
                    }
                }
                .pickerStyle(.menu)
                Hint("Sprinter: \(r.salMonthsSpr)M Gehalt | Standard: \(r.salMonthsStd)M Gehalt")
            }

            IntField(title: "Kündigungsfrist (Monate)", value: m.inputs.fristMonate, info: Info.frist,
                     hint: "Restlaufzeit ab Startmonat. Die Auszahlung wird immer in 2027 angenommen.")
            NumberField(title: "Basis-Abfindung (Brutto €)", value: m.inputs.bruttoAbfindung,
                        info: Info.abfindung, hint: "Ohne Sprinter-Prämie")
            NumberField(title: "Neues Gehalt 2027 (Brutto €)", value: m.inputs.neuesGehalt,
                        info: Info.neuesGehalt, hint: "Nur das Gehalt NACH der Lücke / dem Austritt in 2027 eintragen.")
            NumberField(title: "Fiktives AG-Jahresgehalt (€)", value: m.inputs.agFiktivGehalt,
                        info: Info.agFiktiv, hint: "Basis für Lohnsteuer-Einbehalt")

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: "KV-Zusatzbeitrag (%) & Status", info: Info.gkv)
                HStack {
                    TextField("2,5", value: m.inputs.zusatzbeitrag, format: .number)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                        .frame(maxWidth: 110)
                    Picker("Status", selection: m.inputs.preExitGkvPflicht) {
                        Text("Pflicht (§19)").tag(true)
                        Text("Freiwillig").tag(false)
                    }.pickerStyle(.segmented)
                }
                Hint("GKV-Höchstsatz: ~\(Fmt.eur(r.gkvHoechst))/Mo")
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: "Kinder (Freibetrag)", info: Info.kinder)
                Picker("Kinder", selection: Binding(get: { model.inputs.kinder }, set: { model.setKinder($0) })) {
                    ForEach(kinderOptions, id: \.0) { Text($0.1).tag($0.0) }
                }.pickerStyle(.menu)
                Hint("KFB: \(Fmt.eur(r.kfb)) vs. KG: \(Fmt.eur(r.kg))")
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: "Kirchensteuer", info: Info.kirchensteuer)
                Picker("Kirchensteuer", selection: m.inputs.kirchensteuer) {
                    Text("Keine").tag(0.0)
                    Text("8 % (BY, BW)").tag(0.08)
                    Text("9 % (übrige)").tag(0.09)
                }.pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: "Steuertarif 2027", info: Info.tarif)
                Picker("Tarif", selection: m.inputs.splitting) {
                    Text("Grundtarif").tag(false)
                    Text("Splitting").tag(true)
                }.pickerStyle(.segmented)
            }

            if model.inputs.splitting {
                NumberField(title: "Brutto-Gehalt Partner/in 2027 (€)", value: m.inputs.partnerGehalt,
                            hint: r.splitting.map { "Splitting-Vorteil bis ca. \(Fmt.eur($0.maxPartnerGross)) Partner-Brutto" })
                if let s = r.splitting {
                    if s.advantage >= 0 {
                        Banner(text: "✅ **Splitting-Vorteil (+ \(Fmt.eur(s.advantage))):** Zusammenveranlagung ist bis ca. **\(Fmt.eur(s.maxPartnerGross))** Partner-Brutto günstiger als Einzelveranlagung.", color: Theme.success)
                    } else {
                        Banner(text: "⚠️ **Fünftel-Falle (− \(Fmt.eur(abs(s.advantage)))):** Zusammenveranlagung kostet hier extra! Einzelveranlagung (Grundtarif) prüfen (Grenze: ~\(Fmt.eur(s.maxPartnerGross))).", color: Theme.danger)
                    }
                }
            }
        }
    }

    // MARK: Sprinter

    @ViewBuilder
    private func sprinterCard(m: Bindable<AppModel>, r: Results) -> some View {
        let on = model.inputs.isTurbo
        let badge = on ? "Aktiv (\(r.sprinterNetDiff >= 0 ? "+" : "−")\(Fmt.eur(abs(r.sprinterNetDiff))) Netto-Bilanz)"
                       : "Inaktiv (Frist wird regulär abgesessen)"
        SectionToggle(title: "🚀 Vorzeitiger Austritt / Sprinter-Option", badge: badge, isOn: m.inputs.isTurbo) {
            NumberField(title: "Sprinter-Faktor (pro Monat)", value: m.inputs.turboFaktor, info: Info.sprinterFaktor,
                        hint: "Brutto-Prämie: + \(Fmt.eur(r.sprinterBruttoPraemie))")
            NumberField(title: "Anrechnungsanteil Ruhenszeit (%)", value: m.inputs.ruhensAnteil, info: Info.ruhensAnteil,
                        hint: "Gesetzlich 25–60 %, 60 % = vorsichtig. Ruhenszeit: \(r.ruhensMonthsSprinter) Mon., Sperrzeit kürzt ALG 1 um \(r.sperrzeitMonths) Mon.")
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(title: "ALG 1 Satz (Auto aus Brutto & Kinder)", info: Info.alg1)
                Picker("ALG 1", selection: m.inputs.alg1Satz) {
                    Text("67 % (mit Kind)").tag(0.67)
                    Text("60 % (ohne Kind)").tag(0.60)
                }.pickerStyle(.segmented)
                Hint("ALG 1 Netto: ~\(Fmt.eur(r.alg1Monat))/Mo")
            }
            Toggle("ALG-1-Verlust einrechnen (Anspruch voll ausgeschöpft)", isOn: m.inputs.includeAlg1Loss)
                .font(.subheadline)
            KPITile(label: "Isolierte Netto-Prämie", value: "+ " + Fmt.eur(r.isolatedNettoPraemie),
                    sub: "Nach § 34 EStG Fünftelregelung", color: Theme.success)

            let diff = r.sprinterNetDiff
            if diff >= 0 {
                Banner(text: "✅ **Sprinter-Vorteil (+ \(Fmt.eur(diff))):** Netto-Prämie (+ \(Fmt.eur(r.isolatedNettoPraemie))) & Steuer-Hebel (+ \(Fmt.eur(r.pureFuenftelAdvantage))) überkompensieren Gehaltsverlust & Abzüge.", color: Theme.success)
            } else {
                Banner(text: "⚠️ **Sprinter-Nachteil (− \(Fmt.eur(abs(diff)))):** Gehaltsverlust & Abzüge übersteigen Prämie & Steuer-Hebel.", color: Theme.danger)
            }
            SprinterDetails(r: r)
        }
    }

    // MARK: B. Optimierung

    @ViewBuilder
    private func optimizationCard(m: Bindable<AppModel>, r: Results) -> some View {
        let on = model.inputs.optEnabled
        let badge = on ? "Aktiv (\(Fmt.eur(r.totalOptVolume)))" : "Minimiert (0 €)"
        SectionToggle(title: "🎯 B. Steuer-Optimierung (bAV, DRV V0210, Rürup, PV-IAB)", badge: badge,
                      isOn: Binding(get: { model.inputs.optEnabled }, set: { model.setOptEnabled($0) })) {
            SliderCard(title: "1. bAV-Einzahlung (§ 3 Nr. 63 EStG)", info: Info.bav,
                       valueText: Fmt.eur(r.bav),
                       pill: r.bavSaving.amount > 0 ? "Sofort-Ersparnis: \(Fmt.eur(r.bavSaving.savings)) (\(Fmt.pct(r.bavSaving.percent)))" : nil,
                       value: m.inputs.bav, range: 0...Const.maxBav, step: 500,
                       hint: "Max. 50.976 € (42.480 € Vervielfältiger + 8.496 € 2027-Rahmen, Annahme: 0 € laufende bAV).",
                       explainLabel: r.bavSaving.amount > 0 ? "🛡️ Sofort-Steuerersparnis (2027 Lohnsteuer-Abzug):" : nil,
                       explainValue: "\(Fmt.eur(r.bavSaving.savings)) (\(Fmt.pct(r.bavSaving.percent)))")

            SliderCard(title: "2. AG-Direktzahlung DRV (§ 187a / V0210)", info: Info.drv,
                       valueText: Fmt.eur(r.drvRaw),
                       pill: r.drvSaving.amount > 0 ? "Ersparnis: \(Fmt.eur(r.drvSaving.savings)) (\(Fmt.pct(r.drvSaving.percent)))" : nil,
                       value: m.inputs.drv, range: 0...model.inputs.drvMax, step: 500,
                       hint: "50 % steuerfrei (§ 3 Nr. 28 EStG: \(Fmt.eur(r.drvTaxFree))) ohne Rürup-Cap-Kürzung; 50 % Fünftelregelung.",
                       extraAction: ("🎯 Defizit berechnen", { showDrv = true }),
                       explainLabel: r.drvSaving.amount > 0 ? "💡 Gesamt-Ersparnis (50% Sofort + 50% Fünftel):" : nil,
                       explainValue: "\(Fmt.eur(r.drvSaving.savings)) (\(Fmt.pct(r.drvSaving.percent)))")

            SliderCard(title: "3. Rürup / Basisrente (§ 10 Abs. 1 Nr. 2 EStG)", info: Info.ruerup,
                       valueText: Fmt.eur(r.ruerup),
                       pill: r.ruerupSaving.amount > 0 ? "FA-Erstattung: \(Fmt.eur(r.ruerupSaving.savings)) (\(Fmt.pct(r.ruerupSaving.percent)))" : nil,
                       value: m.inputs.ruerup, range: 0...max(1, jsRound(r.maxRuerup)), step: 250,
                       hint: "Max. Cap 2027: \(Fmt.eur(r.maxRuerup)) (⚠️ Kapital dauerhaft gebunden)",
                       sweetTitle: "🎯 Cash-Plus Sweet-Spot (>100%): \(Fmt.eur(r.ruerupSweetSpot))",
                       sweetAction: { model.applyRuerupSweetSpot() },
                       explainLabel: r.ruerupSaving.amount > 0 ? "💡 Steuer-Erstattung (Okt. 2028 FA):" : nil,
                       explainValue: "\(Fmt.eur(r.ruerupSaving.savings)) (\(Fmt.pct(r.ruerupSaving.percent)))")

            SliderCard(title: "4. Gewerbl. PV-IAB (§ 7g EStG — 50% Abzug)", info: Info.iab,
                       valueText: "\(Fmt.eur(r.iabInvest)) (Abzug: \(Fmt.eur(r.iab)))",
                       pill: r.iabSaving.amount > 0 ? "FA-Erstattung: \(Fmt.eur(r.iabSaving.savings)) (\(Fmt.pct(r.iabSaving.percent)))" : nil,
                       value: m.inputs.iabInvest, range: 0...400_000, step: 2000,
                       hint: "Kaufpreis bis 400.000 € → 50% IAB-Abzug in 2027",
                       sweetTitle: "🎯 IAB Sweet-Spot: \(Fmt.eur(r.iabSweetInvest)) (Abzug: \(Fmt.eur(r.iabSweetAbzug)))",
                       sweetAction: { model.applyIabSweetSpot() },
                       explainLabel: r.iabSaving.amount > 0 ? "💡 Steuer-Erstattung auf Kaufpreis (Okt. 2028):" : nil,
                       explainValue: "\(Fmt.eur(r.iabSaving.savings)) (\(Fmt.pct(r.iabSaving.percent)))")
        }
    }
}
