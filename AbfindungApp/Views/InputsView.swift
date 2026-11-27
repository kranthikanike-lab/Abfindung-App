import SwiftUI

private var monthNames: [String] { [tr("Januar"), tr("Februar"), tr("März"), tr("April"), tr("Mai"), tr("Juni"), tr("Juli"), tr("August"),
                          tr("September"), tr("Oktober"), tr("November"), tr("Dezember")] }
private var kinderOptions: [(Double, String)] { [
    (0, tr("0 Kinder")), (0.5, tr("0,5 (1 Kind geteilt)")), (1, tr("1,0 (1 Kind voll)")),
    (1.5, tr("1,5 Kinder")), (2, tr("2,0 Kinder")), (2.5, tr("2,5 Kinder")), (3, tr("3,0 Kinder"))
] }

struct InputsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var m = model
        let r = model.results
        ScrollView {
            VStack(spacing: 10) {
                coreCard(m: $m, r: r)
                sprinterCard(m: $m, r: r)
            }
            .padding(.horizontal, Theme.pageMargin)
            .padding(.vertical, 12)
            .padding(.bottom, 70)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.pageBackground)
        .navigationTitle("Abfindungs-Optimizer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { AppToolbar(tab: .inputs) }
        .themedBars()
        .safeAreaInset(edge: .bottom) { StickyKPIBar() }
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
            AmountSlider(title: tr("Reguläres Brutto-Monatsgehalt (€)"), value: m.inputs.altesMonatsgehalt,
                         range: 1_000...20_000, step: 100, info: Info.altesGehalt,
                         hint: tr("Jahresbrutto: \(Fmt.eur(r.jahresBrutto))"))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    FieldLabel(title: tr("Start Frist / Sprinter-Austritt 2027"), info: Info.startMonth)
                    Picker(tr("Startmonat"), selection: m.inputs.startMonth) {
                        ForEach(1...12, id: \.self) { n in Text(monthNames[n - 1] + " 2027").tag(n) }
                    }
                    .pickerStyle(.menu)
                }
                Hint(tr("Sprinter: \(r.salMonthsSpr)M Gehalt | Standard: \(r.salMonthsStd)M Gehalt"))
            }

            StepperField(title: tr("Kündigungsfrist (Monate)"), value: m.inputs.fristMonate.asDouble,
                         range: 0...18, step: 1, info: Info.frist,
                         display: { v in tr("\(Int(v)) Mon.") },
                         hint: tr("Restlaufzeit ab Startmonat. Die Auszahlung wird immer in 2027 angenommen."))
            AmountSlider(title: tr("Basis-Abfindung (Brutto €)"), value: m.inputs.bruttoAbfindung,
                         range: 0...700_000, step: 5_000, info: Info.abfindung,
                         hint: tr("Ohne Sprinter-Prämie"))
            AmountSlider(title: tr("Neues Gehalt 2027 (Jahresbetrag, Brutto €)"), value: m.inputs.neuesGehalt,
                         range: 0...200_000, step: 5_000, info: Info.neuesGehalt,
                         hint: tr("Gesamtes Brutto aus dem neuen Job, das 2027 anfällt – als Jahresbetrag, nicht monatlich. Nur die Zeit NACH Austritt / Lücke zählt."))

            VStack(alignment: .leading, spacing: 8) {
                Toggle(tr("Automatisch (12 × Monatsgehalt)"), isOn: m.inputs.agFiktivAuto).font(.subheadline)
                if model.inputs.agFiktivAuto {
                    HStack {
                        FieldLabel(title: tr("Fiktives AG-Jahresgehalt (€)"), info: Info.agFiktiv)
                        Text(Fmt.eur(r.jahresBrutto)).font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent)
                    }
                    Hint(tr("Basis für Lohnsteuer-Einbehalt"))
                } else {
                    AmountSlider(title: tr("Fiktives AG-Jahresgehalt (€)"), value: m.inputs.agFiktivGehalt,
                                 range: 0...300_000, step: 2_500, info: Info.agFiktiv,
                                 hint: tr("Basis für Lohnsteuer-Einbehalt"))
                }
            }

            StepperField(title: tr("KV-Zusatzbeitrag (%)"), value: m.inputs.zusatzbeitrag,
                         range: 0...6, step: 0.1, info: Info.gkv, decimals: 1, suffix: "%",
                         hint: tr("GKV-Höchstsatz: ~\(Fmt.eur(r.gkvHoechst))/Mo"))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    FieldLabel(title: tr("Kinder (Freibetrag)"), info: Info.kinder)
                    Picker(tr("Kinder"), selection: Binding(get: { model.inputs.kinder }, set: { model.setKinder($0) })) {
                        ForEach(kinderOptions, id: \.0) { Text($0.1).tag($0.0) }
                    }.pickerStyle(.menu)
                }
                Hint(tr("KFB: \(Fmt.eur(r.kfb)) vs. KG: \(Fmt.eur(r.kg))"))
            }

            VStack(alignment: .leading, spacing: 4) {
                FieldLabel(title: tr("Kirchensteuer"), info: Info.kirchensteuer)
                Picker(tr("Kirchensteuer"), selection: m.inputs.kirchensteuer) {
                    Text(tr("Keine")).tag(0.0)
                    Text("8 % (BY, BW)").tag(0.08)
                    Text(tr("9 % (übrige)")).tag(0.09)
                }.pickerStyle(.segmented)
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(title: tr("Tarif"), info: Info.tarif)
                    Picker(tr("Tarif"), selection: m.inputs.splitting) {
                        Text(tr("Grundtarif")).tag(false)
                        Text(tr("Splitting")).tag(true)
                    }.pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel(title: tr("Versicherung vor Austritt"), info: Info.gkv)
                    Picker("Status", selection: m.inputs.preExitGkvPflicht) {
                        Text(tr("Pflicht")).tag(true)
                        Text(tr("Freiwillig")).tag(false)
                    }.pickerStyle(.segmented)
                }
            }

            if model.inputs.splitting {
                AmountSlider(title: tr("Brutto-Gehalt Partner/in 2027 (€)"), value: m.inputs.partnerGehalt,
                             range: 0...200_000, step: 2_500,
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
        SectionToggle(title: tr("🚀 Vorzeitiger Austritt / Sprinter-Option"), badge: badge, isOn: m.inputs.isTurbo, info: Info.sprinter) {
            StepperField(title: tr("Sprinter-Faktor (pro Monat)"), value: m.inputs.turboFaktor,
                         range: 0...3, step: 0.1, info: Info.sprinterFaktor, decimals: 1, suffix: "×",
                         hint: tr("Brutto-Prämie: + \(Fmt.eur(r.sprinterBruttoPraemie))"))
            HStack(spacing: 8) {
                StepperTile(title: tr("Alter"), value: m.inputs.alter.asDouble, range: 18...67)
                StepperTile(title: tr("Betriebszugehörigkeit (Jahre)"), value: m.inputs.betriebsjahre.asDouble, range: 0...45)
            }
            InfoRow(title: tr("Anteil der Abfindung für die Ruhenszeit"), value: Fmt.pct(r.ruhensAnteil * 100, digits: 0),
                    info: Info.ruhenszeit, hint: tr("60 % minus 5 Punkte je 5 Jahre Betriebszugehörigkeit und je 5 Jahre Alter über 35, mindestens 25 %"))
            InfoRow(title: tr("Ruhenszeit"), value: tr("\(r.ruhensMonthsSprinter) Mon."), info: Info.ruhenszeit,
                    hint: tr("Abfindung × Anteil ÷ Monatsgehalt, höchstens Kündigungsfrist und 12 Monate"))
            InfoRow(title: tr("Sperrzeit (12 Wochen)"), value: tr("ALG 1 −\(r.sperrzeitMonths) Mon."), info: Info.sperrzeit)
            InfoRow(title: tr("ALG 1 (netto)"), value: tr("~\(Fmt.eur(r.alg1Monat))/Mo"), info: Info.alg1Overview)
            VStack(alignment: .leading, spacing: 4) {
                FieldLabel(title: tr("ALG 1 Satz (Auto aus Brutto & Kinder)"), info: Info.alg1)
                Picker("ALG 1", selection: m.inputs.alg1Satz) {
                    Text(tr("67 % (mit Kind)")).tag(0.67)
                    Text(tr("60 % (ohne Kind)")).tag(0.60)
                }.pickerStyle(.segmented)
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
}
