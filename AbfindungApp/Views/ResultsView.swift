import SwiftUI

struct ResultsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let r = model.results
        ScrollView {
            VStack(spacing: 14) {
                KPIGrid {
                    KPITile(label: "Sofort-Netto Abfindung (2027)", value: Fmt.eur(r.netVoll), sub: "Nach AG-Lohnsteuer-Einbehalt")
                    KPITile(label: "Erstattung Finanzamt (Okt. 2028)", value: "+ " + Fmt.eur(r.erstattung),
                            sub: "Durch Fünftelregelung & Steuerhebel", color: Theme.success)
                    KPITile(label: "Optimal-Netto Abfindung", value: Fmt.eur(r.netFf),
                            sub: "Effektiver Steuersatz: \(Fmt.pct(r.rateFinal))", color: Theme.accent)
                    KPITile(label: "Konto-Cash Ende 2028 (Gesamt)", value: Fmt.eur(r.liq28),
                            sub: "Inkl. Netto-Gehalt 2027 & FA-Erstattung",
                            color: r.liq28 < 0 ? Theme.danger : Theme.success)
                }

                Card(title: "1. AG-Abrechnung (Sofort 2027)") { AgChart(r: r) }
                Card(title: "2. Finanzamt-Endabrechnung (2028)") { FaChart(r: r) }
                Card(title: "3. Zusammensetzung FA-Erstattung (Okt. 2028)") { ErstattungChart(r: r) }

                ResultTable(title: "📋 Tabelle 1: Arbeitgeber-Auszahlung & Lohnsteuer-Einbehalt (2027)",
                            summary: "Sofort-Netto: \(Fmt.eur(r.netVoll))") {
                    TableRow(label: "Basis-Abfindung (Brutto)", value: Fmt.eur(r.abfNoTurbo), note: "Vertragliche Grundabfindung")
                    TableRow(label: "+ Sprinter-Prämie (Brutto)", value: "+ " + Fmt.eur(r.praemieBrutto), note: "Vorzeitiger Austritt")
                    TableRow(label: "= Gesamt-Abfindung (Brutto)", value: Fmt.eur(r.effectiveAbfindung), note: "Vor Vorsorge-Abzügen")
                    TableRow(label: "− bAV-Direktumwandlung (§ 3 Nr. 63)", value: "– " + Fmt.eur(r.bav), note: "100 % steuerfrei (sofortige Lohnsteuer-Ersparnis)")
                    TableRow(label: "− AG-Direktzahlung DRV (V0210)", value: "– " + Fmt.eur(r.drvRaw), note: "50 % steuerfrei (§ 3 Nr. 28 EStG)")
                    TableRow(label: "= Steuerpflichtige Bar-Abfindung", value: Fmt.eur(r.barBruttoTaxable), note: "Bemessungsgrundlage Lohnsteuer")
                    TableRow(label: "− Einbehaltene Lohnsteuer + Soli (\(Fmt.pct(r.rateUpfront)))", value: "– " + Fmt.eur(r.einbehalten),
                             note: "Ohne Fünftelregelung (Wachstumschancengesetz)", color: Theme.danger)
                    TableRow(label: "= Sofort-Netto Auszahlung", value: Fmt.eur(r.netVoll),
                             note: model.inputs.isTurbo ? "Inkl. Sprinter-Prämie" : nil, bold: true)
                }

                ResultTable(title: "🏛️ Tabelle 2: Einkommensteuererklärung & Fünftelregelung (Finanzamt 2028)",
                            summary: "Optimal-Netto: \(Fmt.eur(r.netFf))", summaryColor: Theme.success) {
                    TableRow(label: "Zu versteuerndes Einkommen Basis (zvE_Basis)", value: Fmt.eur(r.zveAfterAll), note: "Nach AN-Pauschbetrag, GKV, Rürup & IAB")
                    TableRow(label: "Steuerpflichtige Abfindung (inkl. 50% DRV V0210)", value: Fmt.eur(r.barBruttoTaxable), note: "Bemessung § 34 Abs. 1 EStG")
                    TableRow(label: "Endgültige Steuer auf Abfindung (\(Fmt.pct(r.rateFinal)))", value: "– " + Fmt.eur(r.finalAbfTax),
                             note: "Nach Fünftelregelung & R 34.2 EStR", color: Theme.danger)
                    TableRow(label: "Erstattung durch Finanzamt (Okt. 2028)", value: "+ " + Fmt.eur(r.erstattung),
                             note: "Differenz aus Vorauszahlung und Endsteuer", color: Theme.success)
                    TableRow(label: "= Optimal-Netto Abfindung (nach FA)", value: Fmt.eur(r.netFf), note: "Realer Netto-Ertrag der Abfindung", bold: true)
                }

                ResultTable(title: "💶 Tabelle 3: Konto-Liquidität & Vermögensbilanz (2027 → Ende 2028)",
                            summary: "Konto Ende 2028: \(Fmt.eur(r.liq28))") {
                    TableRow(label: "+ Sofort-Netto Abfindung", value: "+ " + Fmt.eur(r.netVoll), note: "Auszahlung 2027")
                    TableRow(label: "+ Netto-Gehalt 2027 (nach Steuern & SV)", value: "+ " + Fmt.eur(r.netGehaltBase), note: "Reguläres Gehalt 2027")
                    TableRow(label: "− Eigene Rürup-Einzahlung", value: "– " + Fmt.eur(r.ruerup), note: "Cash-Abfluss 2027 (im Altersvorsorge-Topf gebunden)")
                    TableRow(label: "− PV-IAB Investitions-Abfluss (100% Kaufpreis)", value: "– " + Fmt.eur(r.iabInvest), note: "Hinweis: IAB selbst kostet 2027 0 € Cash (Kauf erst bis 2030)")
                    TableRow(label: "− Freiwillige GKV/PV in Sprinter-Lücke", value: "– " + Fmt.eur(r.gkvPenalty2027), note: "Selbstzahler-Beiträge (§ 10 EStG absetzbar)")
                    TableRow(label: "= Konto-Stand am 31.12.2027", value: Fmt.eur(r.liq27), note: "Vor FA-Erstattung")
                    TableRow(label: "+ Finanzamt-Erstattung (Okt. 2028)", value: "+ " + Fmt.eur(r.erstattung), note: "Steuerbescheid 2027", color: Theme.success)
                    TableRow(label: "= Konto-Stand Ende 2028 (Freie Liquidität)", value: Fmt.eur(r.liq28),
                             note: "Ohne gebundenes bAV/DRV/Rürup/PV-Vermögen", bold: true)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Ergebnis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { AppToolbar() }
    }
}
