import SwiftUI

struct ResultsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let r = model.results
        ScrollView {
            VStack(spacing: 10) {
                KPIGrid {
                    KPITile(label: tr("Sofort-Netto Abfindung (2027)"), value: Fmt.eur(r.netVoll), sub: tr("Nach AG-Lohnsteuer-Einbehalt"))
                    KPITile(label: r.erstattung >= 0 ? tr("Erstattung Finanzamt (Okt. 2028)") : tr("Nachzahlung Finanzamt (Okt. 2028)"),
                            value: Fmt.signedEur(r.erstattung),
                            sub: r.erstattung >= 0 ? tr("Durch Fünftelregelung & Steuerhebel") : tr("Steuer liegt über dem Einbehalt"),
                            color: r.erstattung >= 0 ? Theme.success : Theme.danger)
                    KPITile(label: tr("Optimal-Netto Abfindung"), value: Fmt.eur(r.netFf),
                            sub: tr("Effektiver Steuersatz: \(Fmt.pct(r.rateFinal))"), color: Theme.accent, prominent: true)
                    KPITile(label: tr("Konto-Cash Ende 2028 (Gesamt)"), value: Fmt.eur(r.liq28),
                            sub: tr("Inkl. Netto-Gehalt 2027 & FA-Erstattung"),
                            color: r.liq28 < 0 ? Theme.danger : Theme.success)
                }

                Card(title: tr("1. AG-Abrechnung (Sofort 2027)")) { AgChart(r: r) }
                Card(title: tr("2. Finanzamt-Endabrechnung (2028)")) { FaChart(r: r) }
                if r.bav > 0 || r.drvRaw > 0 || r.ruerup > 0 || r.iabInvest > 0 {
                    Card(title: tr("3. Zusammensetzung FA-Erstattung (Okt. 2028)")) { ErstattungChart(r: r) }
                }

                ResultTable(title: tr("📋 Tabelle 1: Arbeitgeber-Auszahlung & Lohnsteuer-Einbehalt (2027)"),
                            summary: tr("Sofort-Netto: \(Fmt.eur(r.netVoll))")) {
                    TableRow(label: tr("Basis-Abfindung (Brutto)"), value: Fmt.eur(r.abfNoTurbo), note: tr("Vertragliche Grundabfindung"))
                    if r.praemieBrutto > 0 {
                        TableRow(label: tr("+ Sprinter-Prämie (Brutto)"), value: "+ " + Fmt.eur(r.praemieBrutto), note: tr("Vorzeitiger Austritt"))
                        TableRow(label: tr("= Gesamt-Abfindung (Brutto)"), value: Fmt.eur(r.effectiveAbfindung), note: tr("Vor Vorsorge-Abzügen"))
                    }
                    if r.bav > 0 {
                        TableRow(label: tr("− bAV-Direktumwandlung (§ 3 Nr. 63)"), value: "– " + Fmt.eur(r.bav), note: tr("100 % steuerfrei (sofortige Lohnsteuer-Ersparnis)"))
                    }
                    if r.drvRaw > 0 {
                        TableRow(label: tr("− AG-Direktzahlung DRV (V0210)"), value: "– " + Fmt.eur(r.drvRaw), note: tr("50 % steuerfrei (§ 3 Nr. 28 EStG)"))
                    }
                    TableRow(label: tr("= Steuerpflichtige Bar-Abfindung"), value: Fmt.eur(r.barBruttoTaxable), note: tr("Bemessungsgrundlage Lohnsteuer"))
                    TableRow(label: tr("− Einbehaltene Lohnsteuer + Soli\(model.inputs.kirchensteuer > 0 ? tr(" + KiSt") : "") (\(Fmt.pct(r.rateUpfront)))"), value: "– " + Fmt.eur(r.einbehalten),
                             note: tr("Ohne Fünftelregelung (Wachstumschancengesetz)"), color: Theme.danger)
                    if r.kistWithheld > 0 {
                        TableRow(label: tr("   davon Kirchensteuer"), value: "– " + Fmt.eur(r.kistWithheld))
                    }
                    TableRow(label: tr("= Sofort-Netto Auszahlung"), value: Fmt.eur(r.netVoll),
                             note: model.inputs.isTurbo ? tr("Inkl. Sprinter-Prämie") : nil, bold: true)
                }

                ResultTable(title: tr("🏛️ Tabelle 2: Einkommensteuererklärung & Fünftelregelung (Finanzamt 2028)"),
                            summary: tr("Optimal-Netto: \(Fmt.eur(r.netFf))"), summaryColor: Theme.success) {
                    TableRow(label: tr("Zu versteuerndes Einkommen Basis (zvE_Basis)"), value: Fmt.eur(r.zveAfterAll), note: tr("Nach AN-Pauschbetrag, GKV, Rürup & IAB"))
                    TableRow(label: tr("Steuerpflichtige Abfindung (inkl. 50% DRV V0210)"), value: Fmt.eur(r.barBruttoTaxable), note: tr("Bemessung § 34 Abs. 1 EStG"))
                    TableRow(label: tr("Endgültige Steuer auf Abfindung (\(Fmt.pct(r.rateFinal)))"), value: "– " + Fmt.eur(r.finalAbfTax),
                             note: tr("Nach Fünftelregelung & R 34.2 EStR"), color: Theme.danger)
                    if model.inputs.kirchensteuer > 0 {
                        TableRow(label: tr("   davon Kirchensteuer"), value: "– " + Fmt.eur(r.kistFinal))
                    }
                    TableRow(label: r.erstattung >= 0 ? tr("Erstattung durch Finanzamt (Okt. 2028)") : tr("Nachzahlung ans Finanzamt (Okt. 2028)"),
                             value: Fmt.signedEur(r.erstattung),
                             note: tr("Differenz aus Vorauszahlung und Endsteuer"),
                             color: r.erstattung >= 0 ? Theme.success : Theme.danger)
                    TableRow(label: tr("= Optimal-Netto Abfindung (nach FA)"), value: Fmt.eur(r.netFf), note: tr("Realer Netto-Ertrag der Abfindung"), bold: true)
                }

                ResultTable(title: tr("💶 Tabelle 3: Konto-Liquidität & Vermögensbilanz (2027 → Ende 2028)"),
                            summary: tr("Konto Ende 2028: \(Fmt.eur(r.liq28))")) {
                    TableRow(label: tr("+ Sofort-Netto Abfindung"), value: "+ " + Fmt.eur(r.netVoll), note: tr("Auszahlung 2027"))
                    TableRow(label: tr("+ Netto-Gehalt 2027 (nach Steuern & SV)"), value: "+ " + Fmt.eur(r.netGehaltBase), note: tr("Reguläres Gehalt 2027"))
                    if r.ruerup > 0 {
                        TableRow(label: tr("− Eigene Rürup-Einzahlung"), value: "– " + Fmt.eur(r.ruerup), note: tr("Cash-Abfluss 2027 (im Altersvorsorge-Topf gebunden)"))
                    }
                    if r.iabInvest > 0 {
                        TableRow(label: tr("− PV-IAB Investitions-Abfluss (100% Kaufpreis)"), value: "– " + Fmt.eur(r.iabInvest), note: tr("Hinweis: IAB selbst kostet 2027 0 € Cash (Kauf erst bis 2030)"))
                    }
                    if r.gkvPenalty2027 > 0 {
                        TableRow(label: tr("− Freiwillige GKV/PV in Sprinter-Lücke"), value: "– " + Fmt.eur(r.gkvPenalty2027), note: tr("Selbstzahler-Beiträge (§ 10 EStG absetzbar)"))
                    }
                    TableRow(label: tr("= Konto-Stand am 31.12.2027"), value: Fmt.eur(r.liq27), note: tr("Vor FA-Erstattung"))
                    TableRow(label: r.erstattung >= 0 ? tr("+ Finanzamt-Erstattung (Okt. 2028)") : tr("− Finanzamt-Nachzahlung (Okt. 2028)"),
                             value: Fmt.signedEur(r.erstattung), note: tr("Steuerbescheid 2027"),
                             color: r.erstattung >= 0 ? Theme.success : Theme.danger)
                    TableRow(label: tr("= Konto-Stand Ende 2028 (Freie Liquidität)"), value: Fmt.eur(r.liq28),
                             note: tr("Ohne gebundenes bAV/DRV/Rürup/PV-Vermögen"), bold: true)
                }
            }
            .padding(.horizontal, Theme.pageMargin)
            .padding(.vertical, 12)
        }
        .background(Theme.pageBackground)
        .navigationTitle(tr("Ergebnis"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { AppToolbar(tab: .results) }
        .themedBars()
    }
}
