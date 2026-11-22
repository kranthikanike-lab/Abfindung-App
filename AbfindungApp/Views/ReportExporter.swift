import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

/// Renders a one-page PDF report (replaces the browser "Print / PDF" button).
struct ReportFile: Transferable {
    let results: Results
    let inputs: Inputs
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { file in
            let url = await MainActor.run { ReportExporter.makePDF(results: file.results, inputs: file.inputs) }
            guard let url else { throw CocoaError(.fileWriteUnknown) }
            return SentTransferredFile(url)
        }
    }
}

@MainActor
enum ReportExporter {
    static func makePDF(results r: Results, inputs: Inputs) -> URL? {
        let view = ReportView(r: r, i: inputs)
            .frame(width: 595)
            .background(Color.white)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Abfindungs-Report.pdf")
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
        }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

private struct ReportView: View {
    let r: Results
    let i: Inputs
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Abfindungs-Optimizer 2027 – Report").font(.title2.bold())
            Text("Brutto-Monatsgehalt \(Fmt.eur(i.altesMonatsgehalt)) · Abfindung \(Fmt.eur(i.bruttoAbfindung)) · Frist \(i.fristMonate) Mon. · Sprinter: \(i.isTurbo ? "ja" : "nein")")
                .font(.caption).foregroundStyle(.gray)
            Divider()
            row("Basis-Abfindung (Brutto)", Fmt.eur(r.abfNoTurbo))
            if r.praemieBrutto > 0 {
                row("+ Sprinter-Prämie (Brutto)", "+ " + Fmt.eur(r.praemieBrutto))
                row("= Gesamt-Abfindung (Brutto)", Fmt.eur(r.effectiveAbfindung))
            }
            if r.bav > 0 { row("− bAV-Direktumwandlung", "– " + Fmt.eur(r.bav)) }
            if r.drvRaw > 0 { row("− AG-Direktzahlung DRV (V0210)", "– " + Fmt.eur(r.drvRaw)) }
            row("= Steuerpflichtige Bar-Abfindung", Fmt.eur(r.barBruttoTaxable))
            row("− Lohnsteuer\(i.kirchensteuer > 0 ? " + Soli + KiSt" : " + Soli")-Einbehalt (\(Fmt.pct(r.rateUpfront)))", "– " + Fmt.eur(r.einbehalten))
            row("= Sofort-Netto (2027)", Fmt.eur(r.netVoll), bold: true)
            Divider()
            row("Endgültige Steuer auf Abfindung (\(Fmt.pct(r.rateFinal)))", "– " + Fmt.eur(r.finalAbfTax))
            row(r.erstattung >= 0 ? "Erstattung Finanzamt (Okt. 2028)" : "Nachzahlung Finanzamt (Okt. 2028)", Fmt.signedEur(r.erstattung))
            row("= Optimal-Netto Abfindung", Fmt.eur(r.netFf), bold: true)
            Divider()
            if r.ruerup > 0 { row("Rürup-Einzahlung", "– " + Fmt.eur(r.ruerup)) }
            if r.iabInvest > 0 { row("PV-IAB Investition", "– " + Fmt.eur(r.iabInvest)) }
            row("Konto-Stand 31.12.2027", Fmt.eur(r.liq27))
            row("Konto-Stand Ende 2028", Fmt.eur(r.liq28), bold: true)
            if i.isTurbo {
                Divider()
                row("Sprinter-Bilanz (Gewinne − Kosten)", Fmt.signedEur(r.sprinterNetDiff), bold: true)
            }
            Text("Unverbindliche Modellrechnung ohne Gewähr. Ersetzt keine Steuer- oder Rechtsberatung.")
                .font(.caption2).foregroundStyle(.gray).padding(.top, 8)
        }
        .padding(28)
        .foregroundStyle(.black)
    }
    private func row(_ l: String, _ v: String, bold: Bool = false) -> some View {
        HStack { Text(l); Spacer(); Text(v) }
            .font(.system(size: 12, weight: bold ? .bold : .regular))
    }
}
